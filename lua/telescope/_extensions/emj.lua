-- telescope extension: emj
--
-- Provides pickers that fuzzy-search a dataset and insert the selection into
-- the window that was active when the picker opened:
--   :Telescope emj emoji      -> inserts the emoji character   (default)
--   :Telescope emj shortcode  -> inserts the :shortcode: form
--   :Telescope emj nerd       -> inserts a Nerd Font glyph
--
-- When launched from the grid picker (emj_picker.ui), the origin window is
-- passed via opts.emj_origin_win so insertion lands in the right buffer.
local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("emj requires telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local data = require("emj_picker.data")
local insert = require("emj_picker.insert")

-- Flatten the emoji dataset into entries carrying group/subgroup.
local function all_emoji_entries()
  local out = {}
  for _, grp in ipairs(data.groups()) do
    for _, sub in ipairs(grp.subgroups) do
      for _, e in ipairs(sub.emojis) do
        out[#out + 1] = {
          emoji = e.emoji,
          shortcode = e.shortcode,
          group = grp.group,
          subgroup = sub.subgroup,
        }
      end
    end
  end
  return out
end

-- Flatten the Nerd Font dataset into entries carrying the icon-set group.
local function all_nerd_entries()
  local out = {}
  for _, grp in ipairs(data.nerd_groups()) do
    for _, sub in ipairs(grp.subgroups) do
      for _, e in ipairs(sub.glyphs) do
        out[#out + 1] = {
          glyph = e.glyph,
          name = e.name,
          group = grp.group,
        }
      end
    end
  end
  return out
end

-- Build an emoji picker whose confirm action inserts `mode` form of the emoji.
---@param mode "emoji"|"shortcode"
local function make_emoji_picker(mode)
  return function(opts)
    opts = opts or {}
    local origin = opts.emj_origin_win or vim.api.nvim_get_current_win()

    pickers
      .new(opts, {
        prompt_title = mode == "shortcode" and "Emoji (:shortcode:)" or "Emoji",
        finder = finders.new_table({
          results = all_emoji_entries(),
          entry_maker = function(item)
            -- searchable text: shortcode + group + subgroup
            local text = item.shortcode .. " " .. item.group .. " " .. item.subgroup
            local display = string.format("%s  :%s:  (%s)", item.emoji, item.shortcode, item.group)
            return {
              value = item,
              display = display,
              ordinal = text,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not selection then
              return
            end
            local item = selection.value
            local text = insert.text_for({ emoji = item.emoji, shortcode = item.shortcode }, mode)
            insert.insert_at_cursor(origin, text)
          end)
          return true
        end,
      })
      :find()
  end
end

-- Build the Nerd Font picker; confirm inserts the glyph character itself.
local function make_nerd_picker()
  return function(opts)
    opts = opts or {}
    local origin = opts.emj_origin_win or vim.api.nvim_get_current_win()

    pickers
      .new(opts, {
        prompt_title = "Nerd Font",
        finder = finders.new_table({
          results = all_nerd_entries(),
          entry_maker = function(item)
            -- searchable text: full glyph name (prefix included)
            local text = item.name
            local display = string.format("%s  %s", item.glyph, item.name)
            return {
              value = item,
              display = display,
              ordinal = text,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not selection then
              return
            end
            insert.insert_at_cursor(origin, selection.value.glyph)
          end)
          return true
        end,
      })
      :find()
  end
end

local emoji_picker = make_emoji_picker("emoji")
local shortcode_picker = make_emoji_picker("shortcode")
local nerd_picker = make_nerd_picker()

return telescope.register_extension({
  exports = {
    emoji = emoji_picker,
    shortcode = shortcode_picker,
    nerd = nerd_picker,
    -- default when calling `:Telescope emj` with no sub-picker
    emj = emoji_picker,
  },
})
