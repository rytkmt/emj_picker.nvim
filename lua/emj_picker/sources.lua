-- Picker "sources": a source describes WHAT the grid shows (emoji vs Nerd Font
-- glyphs) while ui.lua owns HOW it is rendered and navigated. Both sources
-- expose the same interface so one grid implementation serves both.
--
---@class EmjSourceEntry
---@field glyph string      the character drawn in the grid cell
---@field label string      the name shown in the header (and searched)
---@field raw table         the original dataset entry (passed to text_for)
--
---@class EmjSource
---@field name string                         internal id ("emoji" | "nerd")
---@field title string                        window title base
---@field cell_width integer                  display columns per cell
---@field modes string[]                      insert modes (>=1). mode[1] is default
---@field groups fun(): table[]               ordered groups (group + subgroups)
---@field entries fun(sub: table): EmjSourceEntry[]  normalized entries of a subgroup
---@field text_for fun(raw: table, mode: string): string  text inserted for an entry
---@field mode_label fun(mode: string): string  short label shown in the title
---@field telescope_ext string                telescope extension sub-picker base
local data = require("emj_picker.data")
local insert = require("emj_picker.insert")

local M = {}

-- ---- emoji source ------------------------------------------------------

---@type EmjSource
M.emoji = {
  name = "emoji",
  title = "Emoji Picker",
  cell_width = 4,
  modes = { "emoji", "shortcode" },
  groups = function()
    return data.groups()
  end,
  entries = function(sub)
    local out = {}
    for _, e in ipairs(sub.emojis) do
      out[#out + 1] = { glyph = e.emoji, label = ":" .. e.shortcode .. ":", raw = e }
    end
    return out
  end,
  text_for = function(raw, mode)
    return insert.text_for({ emoji = raw.emoji, shortcode = raw.shortcode }, mode)
  end,
  mode_label = function(mode)
    return mode == "shortcode" and ":shortcode:" or "emoji"
  end,
  telescope_ext = "emj",
}

-- ---- nerd font source --------------------------------------------------

---@type EmjSource
M.nerd = {
  name = "nerd",
  title = "Nerd Font Picker",
  -- Nerd glyphs are nominally single-cell; 3 columns keeps them from touching
  -- while staying denser than the emoji grid.
  cell_width = 3,
  modes = { "glyph" },
  groups = function()
    return data.nerd_groups()
  end,
  entries = function(sub)
    local out = {}
    for _, e in ipairs(sub.glyphs) do
      out[#out + 1] = { glyph = e.glyph, label = e.name, raw = e }
    end
    return out
  end,
  text_for = function(raw, _mode)
    -- Nerd Font has a single insert form: the glyph character itself.
    return raw.glyph
  end,
  mode_label = function(_mode)
    return "glyph"
  end,
  telescope_ext = "emj",
}

return M
