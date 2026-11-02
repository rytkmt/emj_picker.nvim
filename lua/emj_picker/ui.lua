-- Floating-window emoji grid UI.
--
-- A single floating window renders, for the currently selected group:
--   line 1      : status header (insert mode / category)
--   line 2      : separator
--   line 3..    : for each subgroup, a non-selectable heading row followed by
--                 that subgroup's emoji grid (`cell_width` columns per emoji).
--
-- Navigation is grid-based (h/j/k/l) so the user can *scan* emojis visually.
-- Subgroup heading rows are never selectable; vertical movement skips over them.
local config = require("emj_picker.config")
local insert = require("emj_picker.insert")
local sources = require("emj_picker.sources")

local M = {}

local ns = vim.api.nvim_create_namespace("emj_picker")
-- The status line lives in the window's winbar (fixed at the top, never
-- scrolls), so the buffer contains only the grid — no header rows.
local HEADER_LINES = 0

-- forward declaration (defined after state is available)
local header_text

---@class EmjCell
---@field entry EmjSourceEntry
---@field line0 integer    0-based buffer line
---@field col integer      0-based window/byte column of the cell
---@field gcol integer     grid column index within its row
---@field mark integer|nil overlay extmark id

---@class EmjState
---@field buf integer
---@field win integer
---@field origin_win integer
---@field source EmjSource     the active picker source (emoji | nerd)
---@field groups table[]
---@field cat_index integer    1-based index into groups
---@field mode string          current insert mode (one of source.modes)
---@field cols integer
---@field cells EmjCell[]       selectable cells (in display order)
---@field sel integer          1-based index into cells
local state = nil

-- Remembered insert mode across picker invocations, keyed by source name. nil
-- until the user first opens that source; initialized from the source's
-- default mode (or config.default_insert_mode for emoji) then.
local last_mode = {}

---@param win_width integer
local function compute_cols(win_width)
  return math.max(1, math.floor(win_width / state.source.cell_width))
end

---@return EmjGroup current group
local function cur_group()
  return state.groups[state.cat_index]
end

-- Build buffer lines for the current group AND the cell metadata, so that
-- rendering and navigation share one source of truth.
--
-- Emojis are NOT written into the buffer text. Each grid line is filled with
-- plain spaces (one per display column), and emojis are drawn as overlay
-- virtual text at fixed window columns in render(). This makes the grid columns
-- line up regardless of how the terminal actually renders each emoji's width
-- (ZWJ sequences and skin-tone modifiers otherwise break alignment).
---@return string[] lines, EmjCell[] cells
local function build_layout()
  local cw = state.source.cell_width
  local lines = {}
  local cells = {}

  local placeholder = string.rep(" ", state.cols * cw)

  for _, sub in ipairs(cur_group().subgroups) do
    -- non-selectable heading row
    lines[#lines + 1] = "▸ " .. sub.subgroup
    -- grid for this subgroup (normalized via the active source)
    local entries = state.source.entries(sub)
    local n = #entries
    local rows = math.ceil(n / state.cols)
    for r = 0, rows - 1 do
      local line0 = #lines -- 0-based index of the line we are about to add
      for c = 0, state.cols - 1 do
        local idx = r * state.cols + c + 1
        local entry = entries[idx]
        if entry then
          cells[#cells + 1] = {
            entry = entry,
            line0 = line0,
            col = c * cw, -- window/byte column (placeholder is single-byte spaces)
            gcol = c,
          }
        end
      end
      lines[#lines + 1] = placeholder
    end
  end

  return lines, cells
end

-- Draw every glyph as an overlay extmark, highlighting the selected one.
-- Each cell records its extmark id so the selection highlight can later be
-- updated for just the changed cells (the grid can hold thousands of glyphs).
local function draw_emojis()
  local sel_cell = state.cells[state.sel]
  for _, c in ipairs(state.cells) do
    local hl = (c == sel_cell) and "Visual" or nil
    c.mark = vim.api.nvim_buf_set_extmark(state.buf, ns, c.line0, c.col, {
      virt_text = { { c.entry.glyph, hl } },
      virt_text_pos = "overlay",
      hl_mode = "combine",
    })
  end
end

-- Repaint a single cell's overlay extmark with the given highlight group.
---@param cell EmjCell
---@param hl string|nil
local function paint_cell(cell, hl)
  if not cell or not cell.mark then
    return
  end
  vim.api.nvim_buf_set_extmark(state.buf, ns, cell.line0, cell.col, {
    id = cell.mark,
    virt_text = { { cell.entry.glyph, hl } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

-- Force a redraw of the given buffer line range. Repainting an overlay extmark
-- via nvim_buf_set_extmark does not always trigger a screen redraw of that
-- line (the stale glyph lingers until the cursor lands on it), so we nudge the
-- renderer explicitly.
---@param line_from integer 0-based
---@param line_to integer   0-based inclusive
local function redraw_lines(line_from, line_to)
  if vim.api.nvim__redraw then
    pcall(vim.api.nvim__redraw, {
      buf = state.buf,
      range = { math.max(0, line_from), line_to + 1 },
      valid = true,
    })
  else
    vim.cmd("redraw")
  end
end

-- Move the selection highlight from `old` index to the current selection.
local function repaint_selection(old)
  local old_cell = state.cells[old]
  local new_cell = state.cells[state.sel]
  paint_cell(old_cell, nil)
  paint_cell(new_cell, "Visual")
  -- redraw the affected line(s)
  local lo = old_cell and old_cell.line0 or new_cell.line0
  local hi = old_cell and old_cell.line0 or new_cell.line0
  if new_cell then
    lo = math.min(lo, new_cell.line0)
    hi = math.max(hi, new_cell.line0)
  end
  redraw_lines(lo, hi)
end

local function render()
  state.cols = compute_cols(vim.api.nvim_win_get_width(state.win))
  local lines, cells = build_layout()
  state.cells = cells
  if state.sel > #cells then
    state.sel = #cells
  end
  if state.sel < 1 then
    state.sel = 1
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  M.redraw_highlights()
  draw_emojis()
  M.move_cursor_to_selection()
  M.update_header()
  redraw_lines(0, vim.api.nvim_buf_line_count(state.buf) - 1)
end

-- Subgroup heading highlights. (The status line is the winbar; glyph/selection
-- highlights are drawn separately as overlay extmarks in draw_emojis.)
function M.redraw_highlights()
  local total = vim.api.nvim_buf_line_count(state.buf)
  local buf_lines = vim.api.nvim_buf_get_lines(state.buf, 0, total, false)
  for i = HEADER_LINES, total - 1 do
    if buf_lines[i + 1] and buf_lines[i + 1]:match("^▸ ") then
      vim.api.nvim_buf_add_highlight(state.buf, ns, "Directory", i, 0, -1)
    end
  end
end

function M.move_cursor_to_selection()
  local cell = state.cells[state.sel]
  if not cell then
    return
  end
  pcall(vim.api.nvim_win_set_cursor, state.win, { cell.line0 + 1, cell.col })
end

-- Build the status header string (group / position / selected label).
header_text = function()
  local cell = state.cells[state.sel]
  local label = cell and cell.entry.label or ""
  return string.format(
    "%s (%d/%d)   %s",
    cur_group().group,
    state.cat_index,
    #state.groups,
    label
  )
end

-- Update the window's winbar (the fixed status line at the top of the window).
-- Using the winbar keeps the status visible even when the grid scrolls.
function M.update_header()
  if not state or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  -- Escape '%' so winbar does not interpret it as a statusline item, then wrap
  -- in a Title highlight group.
  local text = header_text():gsub("%%", "%%%%")
  vim.wo[state.win].winbar = "%#Title#" .. text
end

-- Put the picker name and the current insert mode in the window title (on the
-- border), e.g. " Emoji Picker — [emoji] " or " Nerd Font Picker — [glyph] ".
function M.update_title()
  if not state or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local base = state.source.title
  local mode_label = state.source.mode_label(state.mode)
  local title = string.format(" %s — [%s] ", base, mode_label)
  pcall(vim.api.nvim_win_set_config, state.win, {
    title = title,
    title_pos = config.options.window.title_pos,
  })
end

-- ---- navigation --------------------------------------------------------

-- Find the cell on a given line whose grid column is closest to `gcol`.
---@param line0 integer
---@param gcol integer
---@return integer|nil cell index
local function cell_on_line(line0, gcol)
  local best, best_dist
  for i, c in ipairs(state.cells) do
    if c.line0 == line0 then
      local d = math.abs(c.gcol - gcol)
      if not best_dist or d < best_dist then
        best, best_dist = i, d
      end
    end
  end
  return best
end

-- Move vertically: from the current cell, scan lines upward/downward until a
-- line that contains emoji cells is found (skipping heading rows), then pick
-- the cell nearest the current grid column.
---@param step integer -1 (up) or 1 (down)
local function vertical(step)
  local cur = state.cells[state.sel]
  if not cur then
    return
  end
  local last_line = state.cells[#state.cells].line0
  local line0 = cur.line0 + step
  while line0 >= HEADER_LINES and line0 <= last_line do
    local idx = cell_on_line(line0, cur.gcol)
    if idx then
      state.sel = idx
      return
    end
    line0 = line0 + step
  end
end

function M.nav(dir, count)
  if #state.cells == 0 then
    return
  end
  count = count or 1
  local old = state.sel
  if dir == "left" then
    state.sel = math.max(1, state.sel - 1)
  elseif dir == "right" then
    state.sel = math.min(#state.cells, state.sel + 1)
  elseif dir == "up" then
    for _ = 1, count do vertical(-1) end
  elseif dir == "down" then
    for _ = 1, count do vertical(1) end
  elseif dir == "home" then
    state.sel = 1
  elseif dir == "end" then
    state.sel = #state.cells
  elseif dir == "line_home" then
    local cur = state.cells[state.sel]
    if cur then
      -- first selectable cell sharing the current buffer line
      for i = state.sel, 1, -1 do
        if state.cells[i].line0 == cur.line0 then
          state.sel = i
        else
          break
        end
      end
    end
  elseif dir == "line_end" then
    local cur = state.cells[state.sel]
    if cur then
      -- last selectable cell sharing the current buffer line
      for i = state.sel, #state.cells do
        if state.cells[i].line0 == cur.line0 then
          state.sel = i
        else
          break
        end
      end
    end
  end
  repaint_selection(old)
  M.move_cursor_to_selection()
  M.update_header()
end

function M.switch_category(delta)
  local max = #state.groups
  state.cat_index = state.cat_index + delta
  if state.cat_index < 1 then
    state.cat_index = max
  elseif state.cat_index > max then
    state.cat_index = 1
  end
  state.sel = 1
  render()
end

-- Cycle to the next insert mode offered by the active source. Sources with a
-- single mode (e.g. Nerd Font) effectively make this a no-op.
function M.toggle_mode()
  local modes = state.source.modes
  if #modes < 2 then
    return
  end
  local i = 1
  for idx, m in ipairs(modes) do
    if m == state.mode then
      i = idx
      break
    end
  end
  state.mode = modes[(i % #modes) + 1]
  last_mode[state.source.name] = state.mode
  M.update_title()
  render()
end

function M.confirm()
  local cell = state.cells[state.sel]
  if not cell then
    return
  end
  local text = state.source.text_for(cell.entry.raw, state.mode)
  local origin = state.origin_win
  M.close()
  insert.insert_at_cursor(origin, text)
end

-- ---- filtering ---------------------------------------------------------

-- ---- search (delegated to telescope) -----------------------------------

-- Open the telescope picker for the active source, inserting into the same
-- origin window the grid would insert into. Closes the grid first. No-op with
-- a notice if telescope (or this plugin's extension) is unavailable.
function M.search()
  local origin = state.origin_win
  local source = state.source
  local mode = state.mode
  local ok_tel = pcall(require, "telescope")
  if not ok_tel then
    vim.notify("emj_picker: telescope.nvim is not installed", vim.log.levels.WARN)
    return
  end
  M.close()
  local telescope = require("telescope")
  pcall(telescope.load_extension, "emj")
  local ext = telescope.extensions and telescope.extensions.emj
  if not ext then
    vim.notify("emj_picker: telescope extension 'emj' failed to load", vim.log.levels.WARN)
    return
  end
  -- Pick the telescope sub-picker matching the source/mode.
  local picker
  if source.name == "nerd" then
    picker = ext.nerd
  else
    picker = (mode == "shortcode") and ext.shortcode or ext.emoji
  end
  if not picker then
    vim.notify("emj_picker: telescope picker unavailable", vim.log.levels.WARN)
    return
  end
  picker({ emj_origin_win = origin })
end

function M.close()
  if state and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state = nil
end

-- ---- keymaps -----------------------------------------------------------

local function map(lhs_list, fn)
  for _, lhs in ipairs(lhs_list) do
    vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true })
  end
end

local function setup_keymaps()
  local k = config.options.keymaps
  map(k.close, M.close)
  map(k.confirm, M.confirm)
  map(k.toggle_mode, M.toggle_mode)
  map(k.next_category, function() M.switch_category(1) end)
  map(k.prev_category, function() M.switch_category(-1) end)
  map(k.line_home, function() M.nav("line_home") end)
  map(k.line_end, function() M.nav("line_end") end)
  map(k.search, M.search)
  map(k.nav_left, function() M.nav("left") end)
  map(k.nav_right, function() M.nav("right") end)
  map(k.nav_down, function() M.nav("down") end)
  map(k.nav_up, function() M.nav("up") end)
  map(k.page_down, function() M.nav("down", config.options.scroll_step) end)
  map(k.page_up, function() M.nav("up", config.options.scroll_step) end)
  map({ "gg" }, function() M.nav("home") end)
  map({ "G" }, function() M.nav("end") end)
end

-- ---- open --------------------------------------------------------------

---@param n number ratio (0..1) or absolute (>=1)
---@param total integer
local function resolve_dim(n, total)
  if n <= 1 then
    return math.floor(total * n)
  end
  return math.floor(n)
end

-- Open the picker for the given source ("emoji" by default).
---@param source_name? "emoji"|"nerd"
function M.open(source_name)
  if state then
    M.close()
  end
  local source = sources[source_name or "emoji"] or sources.emoji
  local cfg = config.options
  local origin_win = vim.api.nvim_get_current_win()

  local width = math.max(20, resolve_dim(cfg.window.width, vim.o.columns))
  local height = math.max(6, resolve_dim(cfg.window.height, vim.o.lines))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "emj_picker"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = cfg.window.border,
    title = cfg.window.title,
    title_pos = cfg.window.title_pos,
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  -- Resolve the initial insert mode for this source: remembered -> config
  -- default (if valid for the source) -> source's own first mode.
  local function initial_mode()
    if last_mode[source.name] then
      return last_mode[source.name]
    end
    for _, m in ipairs(source.modes) do
      if m == cfg.default_insert_mode then
        return m
      end
    end
    return source.modes[1]
  end

  state = {
    buf = buf,
    win = win,
    origin_win = origin_win,
    source = source,
    groups = source.groups(),
    cat_index = 1,
    mode = initial_mode(),
    cols = 1,
    cells = {},
    sel = 1,
  }

  setup_keymaps()
  render()
  M.update_title()

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = buf,
    once = true,
    callback = function()
      state = nil
    end,
  })
end

return M
