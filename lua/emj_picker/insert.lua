-- Inserting the chosen emoji into the window/buffer that was active before the
-- picker opened.
local M = {}

---@param win integer window id to insert into
---@param text string text to insert at the cursor
function M.insert_at_cursor(win, text)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row = cursor[1] - 1 -- 0-indexed line
  local col = cursor[2] -- byte column
  vim.api.nvim_buf_set_text(buf, row, col, row, col, { text })
  -- move cursor to just after the inserted text
  vim.api.nvim_win_set_cursor(win, { row + 1, col + #text })
end

---@param item EmjItem
---@param mode "emoji"|"shortcode"
---@return string
function M.text_for(item, mode)
  if mode == "shortcode" then
    return ":" .. item.shortcode .. ":"
  end
  return item.emoji
end

return M
