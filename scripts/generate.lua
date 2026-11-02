-- Regenerate lua/emj_picker/data/emojis.lua from the official Unicode
-- emoji-test.txt. No dependency on icon-picker.nvim: emoji, names and
-- group/subgroup classification all come from Unicode.
--
-- Usage (from the repo root):
--   nvim --headless -l scripts/generate.lua
--
-- Output is an *ordered* hierarchy so the picker can present emojis in the
-- official Unicode order (which is grouped by topic):
--
--   return {
--     { group = "Smileys & Emotion", subgroups = {
--       { subgroup = "face-smiling", emojis = {
--         { emoji = "😀", shortcode = "grinning_face" },
--         ...
--   }
--
-- Source data: https://unicode.org/Public/emoji/latest/emoji-test.txt
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = vim.fn.fnamemodify(script_path, ":h")
local repo_root = vim.fn.fnamemodify(script_dir, ":h")

local src = script_dir .. "/emoji-test.txt"
local raw_lines = vim.fn.readfile(src)

-- "grinning face" / "flag: Japan" -> "grinning_face" / "flag_japan"
local function slug(name)
  local s = name:lower()
  s = s:gsub("[’'`]", "")
  s = s:gsub("[^%w]+", "_")
  s = s:gsub("^_+", ""):gsub("_+$", "")
  return s
end

-- "1F600 1F3FB" -> actual emoji string
local function cps_to_emoji(spec)
  local out = {}
  for hex in spec:gmatch("%x+") do
    out[#out + 1] = vim.fn.nr2char(tonumber(hex, 16))
  end
  return table.concat(out)
end

-- Whether a codepoint spec contains a skin-tone modifier (U+1F3FB..U+1F3FF) or
-- a ZWJ (U+200D) joining several codepoints into one glyph. Such emojis render
-- at an inconsistent display width across terminals/fonts, which breaks the
-- grid alignment, so they are excluded from the dataset. Only single-codepoint
-- emojis (optionally with a VS16 U+FE0F) are kept.
local function is_variant(spec)
  for hex in spec:gmatch("%x+") do
    local cp = tonumber(hex, 16)
    if cp == 0x200D then -- ZWJ
      return true
    end
    if cp >= 0x1F3FB and cp <= 0x1F3FF then -- skin-tone modifier
      return true
    end
  end
  return false
end

-- Build an ordered hierarchy. We keep insertion order via arrays, and use
-- index maps only to find the current group/subgroup bucket quickly.
local groups = {} -- array of { group=, subgroups={ array of { subgroup=, emojis={} } } }
local group_idx = {} -- group name -> index in `groups`
local cur_group = nil -- current group bucket
local cur_sub = nil -- current subgroup bucket

for _, line in ipairs(raw_lines) do
  local g = line:match("^# group:%s*(.+)$")
  if g then
    g = vim.trim(g)
    if g == "Component" then
      -- skin-tone / hair components are not standalone emojis; skip the group
      cur_group = nil
      cur_sub = nil
    else
      if not group_idx[g] then
        groups[#groups + 1] = { group = g, subgroups = {} }
        group_idx[g] = #groups
      end
      cur_group = groups[group_idx[g]]
      cur_sub = nil
    end
  end

  local sg = line:match("^# subgroup:%s*(.+)$")
  if sg and cur_group then
    sg = vim.trim(sg)
    cur_sub = { subgroup = sg, emojis = {} }
    cur_group.subgroups[#cur_group.subgroups + 1] = cur_sub
  end

  -- data line: "<cps> ; fully-qualified  # <emoji> E<ver> <name>"
  if not line:match("^#") and line:match(";") and cur_sub then
    local cps, status = line:match("^([%x%s]+);%s*([%w%-]+)")
    if cps and status == "fully-qualified" then
      local name = line:match("#%s*%S+%s+E[%d%.]+%s+(.+)$")
      if name and not is_variant(cps) then
        name = vim.trim(name)
        cps = vim.trim(cps)
        cur_sub.emojis[#cur_sub.emojis + 1] = {
          emoji = cps_to_emoji(cps),
          shortcode = slug(name),
        }
      end
    end
  end
end

local function q(s)
  return '"' .. (s:gsub("\\", "\\\\"):gsub('"', '\\"')) .. '"'
end

local lines = {
  "-- Auto-generated from scripts/emoji-test.txt (official Unicode emoji data).",
  "-- Source: https://unicode.org/Public/emoji/latest/emoji-test.txt",
  "-- DO NOT EDIT MANUALLY. Regenerate via: nvim --headless -l scripts/generate.lua",
  "--",
  "-- Shape: ordered array of groups; each group has ordered subgroups; each",
  "-- subgroup has ordered emoji entries { emoji, shortcode }.",
  "return {",
}

local total = 0
for _, grp in ipairs(groups) do
  -- collect non-empty subgroups first so empty groups can be skipped entirely
  local sub_blocks = {}
  for _, sub in ipairs(grp.subgroups) do
    if #sub.emojis > 0 then
      local block = { string.format("    { subgroup = %s, emojis = {", q(sub.subgroup)) }
      for _, e in ipairs(sub.emojis) do
        block[#block + 1] = string.format("      { emoji = %s, shortcode = %s },", q(e.emoji), q(e.shortcode))
        total = total + 1
      end
      block[#block + 1] = "    } },"
      sub_blocks[#sub_blocks + 1] = block
    end
  end
  if #sub_blocks > 0 then
    lines[#lines + 1] = string.format("  { group = %s, subgroups = {", q(grp.group))
    for _, block in ipairs(sub_blocks) do
      for _, l in ipairs(block) do
        lines[#lines + 1] = l
      end
    end
    lines[#lines + 1] = "  } },"
  end
end
lines[#lines + 1] = "}"

local out = repo_root .. "/lua/emj_picker/data/emojis.lua"
vim.fn.writefile(lines, out)
print(string.format("wrote %d emojis across %d groups to %s", total, #groups, out))
