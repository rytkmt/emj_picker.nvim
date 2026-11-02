-- emj_picker configuration
local M = {}

---@class EmjPickerKeymaps
---@field close string|string[]        Close the picker
---@field confirm string|string[]      Insert the emoji under cursor
---@field toggle_mode string|string[]  Toggle insert mode (emoji <-> shortcode)
---@field next_category string|string[]
---@field prev_category string|string[]
---@field nav_left string|string[]     Move selection left
---@field nav_right string|string[]    Move selection right
---@field nav_up string|string[]       Move selection up
---@field nav_down string|string[]     Move selection down
---@field page_up string|string[]      Move selection up by scroll_step rows
---@field page_down string|string[]    Move selection down by scroll_step rows
---@field line_home string|string[]    Jump to the first cell on the current row
---@field line_end string|string[]     Jump to the last cell on the current row
---@field search string|string[]        Open the telescope search for the current mode

---@class EmjPickerWindow
---@field width number   Columns. Integer >=1 = absolute; float 0..1 = ratio of editor width
---@field height number  Rows.    Integer >=1 = absolute; float 0..1 = ratio of editor height
---@field border string|string[] Any value accepted by nvim_open_win 'border'
---@field title string
---@field title_pos "left"|"center"|"right"

---@class EmjPickerConfig
---@field window EmjPickerWindow
---@field keymaps EmjPickerKeymaps
---@field default_insert_mode "emoji"|"shortcode"
---@field cell_width number   Display width reserved per emoji cell
---@field scroll_step number  Rows moved per page_up/page_down keymap

---@type EmjPickerConfig
M.defaults = {
  window = {
    width = 0.6,
    height = 0.7,
    border = "rounded",
    title = " Emoji Picker ",
    title_pos = "center",
  },
  keymaps = {
    close = { "<Esc>", "q" },
    confirm = { "<CR>" },
    toggle_mode = { "<Tab>" },
    next_category = { "]" },
    prev_category = { "[" },
    nav_left = { "h", "b" },
    nav_right = { "l", "w", "e" },
    nav_up = { "k" },
    nav_down = { "j" },
    page_up = { "K" },
    page_down = { "J" },
    line_home = { "H" },
    line_end = { "L" },
    search = { "/" },
  },
  default_insert_mode = "emoji",
  cell_width = 4,
  scroll_step = 3,
}

---@type EmjPickerConfig
M.options = vim.deepcopy(M.defaults)

---@param opts? table
---@return EmjPickerConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  -- normalize single-string keymaps into lists
  for key, val in pairs(M.options.keymaps) do
    if type(val) == "string" then
      M.options.keymaps[key] = { val }
    end
  end
  return M.options
end

return M
