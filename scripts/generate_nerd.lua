-- Regenerate lua/emj_picker/data/nerdfonts.lua from the Nerd Fonts
-- glyphnames.json (the canonical list of every patched glyph).
--
-- Usage (from the repo root):
--   nvim --headless -l scripts/generate_nerd.lua
--
-- Source data: https://github.com/ryanoasis/nerd-fonts/blob/master/glyphnames.json
--
-- glyphnames.json is a flat object:
--   { "METADATA": {...},
--     "cod-account": { "char": "", "code": "eb99" },
--     "md-account":  { "char": "", "code": "..." }, ... }
--
-- The key is "<prefix>-<name>" where <prefix> is the icon set (md = Material
-- Design, fa = Font Awesome, dev = Devicons, cod = Codicons, oct = Octicons,
-- weather, seti, linux, custom, ...). We use the prefix as the category.
--
-- Output mirrors the emoji dataset shape so the grid UI can consume both:
--   return {
--     { group = "md", subgroups = {
--       { subgroup = "md", glyphs = { { glyph = "", name = "md-account" }, ... } },
--     } },
--     ...
--   }
-- Nerd Font has no official subgroup hierarchy, so each group has a single
-- subgroup bearing the same (prefix) name. Groups are ordered by descending
-- glyph count so the largest sets come first.
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = vim.fn.fnamemodify(script_path, ":h")
local repo_root = vim.fn.fnamemodify(script_dir, ":h")

local src = script_dir .. "/glyphnames.json"
local raw = table.concat(vim.fn.readfile(src), "\n")
local decoded = vim.fn.json_decode(raw)

-- Collect glyphs bucketed by prefix, preserving first-seen order within a
-- bucket (json_decode does not preserve object key order, so we sort names).
local buckets = {} -- prefix -> array of { glyph, name }
local prefixes = {} -- prefix -> true (presence)

for name, info in pairs(decoded) do
  if name ~= "METADATA" and type(info) == "table" and info.char then
    local prefix = name:match("^([^%-]+)%-") or name
    if not buckets[prefix] then
      buckets[prefix] = {}
      prefixes[prefix] = true
    end
    buckets[prefix][#buckets[prefix] + 1] = { glyph = info.char, name = name }
  end
end

-- Sort glyphs within each bucket by name for a stable, predictable order.
local prefix_list = {}
for p in pairs(prefixes) do
  prefix_list[#prefix_list + 1] = p
  table.sort(buckets[p], function(a, b)
    return a.name < b.name
  end)
end

-- Order groups by descending glyph count (largest icon set first), tie-break
-- by prefix name for determinism.
table.sort(prefix_list, function(a, b)
  if #buckets[a] ~= #buckets[b] then
    return #buckets[a] > #buckets[b]
  end
  return a < b
end)

local function q(s)
  return '"' .. (s:gsub("\\", "\\\\"):gsub('"', '\\"')) .. '"'
end

local lines = {
  "-- Auto-generated from scripts/glyphnames.json (Nerd Fonts glyph list).",
  "-- Source: https://github.com/ryanoasis/nerd-fonts/blob/master/glyphnames.json",
  "-- DO NOT EDIT MANUALLY. Regenerate via: nvim --headless -l scripts/generate_nerd.lua",
  "--",
  "-- Shape mirrors the emoji dataset: ordered array of groups; each group has",
  "-- one subgroup (same prefix name); each subgroup has ordered glyph entries",
  "-- { glyph, name }.",
  "return {",
}

local total = 0
for _, prefix in ipairs(prefix_list) do
  lines[#lines + 1] = string.format("  { group = %s, subgroups = {", q(prefix))
  lines[#lines + 1] = string.format("    { subgroup = %s, glyphs = {", q(prefix))
  for _, e in ipairs(buckets[prefix]) do
    lines[#lines + 1] = string.format("      { glyph = %s, name = %s },", q(e.glyph), q(e.name))
    total = total + 1
  end
  lines[#lines + 1] = "    } },"
  lines[#lines + 1] = "  } },"
end
lines[#lines + 1] = "}"

local out = repo_root .. "/lua/emj_picker/data/nerdfonts.lua"
vim.fn.writefile(lines, out)
print(string.format("wrote %d glyphs across %d groups to %s", total, #prefix_list, out))
