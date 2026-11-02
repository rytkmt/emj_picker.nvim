-- emj_picker.nvim
-- A floating-window emoji picker: scan emojis visually in a grid and insert
-- either the emoji itself or its `:shortcode:` markdown form.
local config = require("emj_picker.config")

local M = {}

---@param opts? table user configuration (see config.defaults)
function M.setup(opts)
  config.setup(opts)
end

-- Open the emoji picker.
function M.pick()
  require("emj_picker.ui").open("emoji")
end

-- Open the Nerd Font glyph picker.
function M.pick_nerd()
  require("emj_picker.ui").open("nerd")
end

return M
