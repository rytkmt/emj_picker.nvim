-- Defines the :EmjPicker user command.
if vim.g.loaded_emj_picker then
  return
end
vim.g.loaded_emj_picker = true

vim.api.nvim_create_user_command("EmjPicker", function()
  require("emj_picker").pick()
end, { desc = "Open the emoji picker" })

vim.api.nvim_create_user_command("EmjPickerNerd", function()
  require("emj_picker").pick_nerd()
end, { desc = "Open the Nerd Font glyph picker" })
