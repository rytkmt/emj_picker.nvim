-- Access to the emoji dataset.
--
-- The dataset (lua/emj_picker/data/emojis.lua) is an ordered hierarchy:
--   { { group = "...", subgroups = { { subgroup = "...", emojis = { {emoji, shortcode}, ... } } } } }
-- preserving the official Unicode ordering.
local M = {}

---@class EmjEntry
---@field emoji string
---@field shortcode string

---@class EmjSubgroup
---@field subgroup string
---@field emojis EmjEntry[]

---@class EmjGroup
---@field group string
---@field subgroups EmjSubgroup[]

-- The source hierarchy: ordered groups -> ordered subgroups -> ordered emojis.
---@return EmjGroup[]
function M.groups()
  return require("emj_picker.data.emojis")
end

---@class NerdEntry
---@field glyph string
---@field name string

---@class NerdSubgroup
---@field subgroup string
---@field glyphs NerdEntry[]

---@class NerdGroup
---@field group string
---@field subgroups NerdSubgroup[]

-- The Nerd Font glyph hierarchy: ordered groups (by icon-set prefix) -> one
-- subgroup each -> ordered glyph entries { glyph, name }.
---@return NerdGroup[]
function M.nerd_groups()
  return require("emj_picker.data.nerdfonts")
end

return M
