# emj_picker.nvim

A floating-window **emoji picker** for Neovim. Instead of typing a keyword and
hoping it matches (as completion-based tools like `cmp-emoji` require), you can
**scan a grid of emojis visually**, grouped by category, and insert the one you
want.

Each emoji can be inserted in one of two modes, toggled live inside the picker:

- **emoji** — inserts the emoji character itself (e.g. `❤️`)
- **shortcode** — inserts the markdown form (e.g. `:red_heart:`)

The emoji dataset is generated directly from the official
[Unicode emoji-test.txt](https://unicode.org/Public/emoji/latest/emoji-test.txt),
so emojis, names and category grouping all come from the Unicode source.

## Features

- Floating window with a scannable emoji **grid** (not just a prompt list)
- **Category grouping** using the official Unicode emoji groups
  (Smileys & Emotion, People & Body, Animals & Nature, Food & Drink,
  Travel & Places, Activities, Objects, Symbols, Flags)
- **Two insert modes** (emoji / `:shortcode:`) with a live toggle key
- A second picker for **Nerd Font glyphs** (`:EmjPickerNerd`) using the same
  grid UI, grouped by icon set (Material Design, Font Awesome, Devicons, …)
- Configurable window size, border (telescope-style), and keymaps
- Optional **fuzzy search** via a [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  extension — press `/` inside the grid, or run `:Telescope emj`

## Requirements

- Neovim >= 0.9 (uses floating-window `title`/`footer`)
- A [Nerd Font](https://www.nerdfonts.com/) patched font *(only for
  `:EmjPickerNerd`)* — without one, Nerd Font glyphs render as tofu (□). The
  emoji picker does not need it.
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) *(optional)*
  — only needed for fuzzy search (`/` in the grid, or `:Telescope emj`).
  The grid picker works without it.

## Installation

The grid picker has no required dependencies. [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
is only needed if you want the fuzzy search (`/` in the grid, or `:Telescope emj`).

This plugin does **not** define any global keymap to open the picker. Out of
the box you open it with the `:EmjPicker` / `:EmjPickerNerd` commands (or the
Lua API). The `<leader>ie` / `<leader>in` below are just an **example** — map
whatever you like, or none.

### lazy.nvim

```lua
{
  "rytkmt/emj_picker.nvim",
  cmd = { "EmjPicker", "EmjPickerNerd" },
  -- example keymaps (optional; the plugin sets none of its own):
  keys = {
    { "<leader>ie", "<cmd>EmjPicker<cr>", desc = "Emoji picker" },
    { "<leader>in", "<cmd>EmjPickerNerd<cr>", desc = "Nerd Font picker" },
  },
  opts = {},
}
```

### packer.nvim

```lua
use({
  "rytkmt/emj_picker.nvim",
  config = function()
    require("emj_picker").setup({})
  end,
})
```

## Usage

Run `:EmjPicker` or call `require("emj_picker").pick()`.

Inside the picker:

| Key         | Action                                          |
| ----------- | ----------------------------------------------- |
| `h/j/k/l`   | Move around the grid                            |
| `w` / `e`   | Move right (same as `l`)                        |
| `b`         | Move left (same as `h`)                         |
| `J` / `K`   | Move down / up by `scroll_step` rows (default 3) |
| `H` / `L`   | Jump to the first / last cell on the current row |
| `gg` / `G`  | Jump to first / last emoji                      |
| `<CR>`      | Insert the selected emoji (in the current mode) |
| `<Tab>`     | Toggle insert mode (emoji ⇄ `:shortcode:`)      |
| `]` / `[`   | Next / previous category                        |
| `/`         | Fuzzy search via telescope (current mode)       |
| `<Esc>`/`q` | Close the picker                                |

The status line (shown in the window's winbar, pinned to the top so it stays
visible while the grid scrolls) shows the current category and position
(`name (n/9)`) along with the selected emoji's shortcode; the current insert
mode is shown in the window title on the border (e.g. `Emoji Picker — [emoji]`).

### Fuzzy search (telescope)

With [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
installed, you can fuzzy-search the whole dataset instead of scanning the grid:

- Press `/` inside the grid to open telescope in the current insert mode. The
  selection is inserted back into the window you started from.
- Or run it directly:
  - `:Telescope emj` / `:Telescope emj emoji` — insert the emoji character
  - `:Telescope emj shortcode` — insert the `:shortcode:` form

Search matches against the shortcode, group and subgroup. No extra setup is
required; the extension is registered lazily on first use (and `/` falls back
to a notice if telescope is not installed).

## Nerd Font picker

Run `:EmjPickerNerd` (or `require("emj_picker").pick_nerd()`) to open the same
grid UI over the [Nerd Font](https://www.nerdfonts.com/) glyph set instead of
emojis. It needs a Nerd Font patched font to render the glyphs.

Differences from the emoji picker:

- There is a **single insert form** — the glyph character itself — so `<Tab>`
  (toggle mode) is a no-op here.
- Categories are the **icon sets** (`md` = Material Design, `fa` = Font Awesome,
  `dev` = Devicons, `cod` = Codicons, `oct` = Octicons, `weather`, `seti`,
  `linux`, …), ordered largest-first. The header shows the full glyph name
  (e.g. `md-account`).
- `/` opens telescope over the glyph set (matching against the glyph name). You
  can also run it directly with `:Telescope emj nerd`.

All other keys (`h/j/k/l`, `gg`/`G`, `]`/`[`, `<CR>`, `<Esc>`/`q`) behave the
same as in the emoji grid.

The glyph dataset is generated from the Nerd Fonts `glyphnames.json`
(10995 glyphs across 17 icon sets); see [Nerd Font data](#nerd-font-data).

## Configuration

`setup()` is optional. Defaults:

```lua
require("emj_picker").setup({
  window = {
    width = 0.6,          -- integer = absolute columns; float 0..1 = ratio of editor width
    height = 0.7,         -- integer = absolute rows;    float 0..1 = ratio of editor height
    border = "rounded",   -- any value accepted by nvim_open_win 'border'
    title = " Emoji Picker ",
    title_pos = "center", -- "left" | "center" | "right"
  },
  keymaps = {
    close = { "<Esc>", "q" },
    confirm = { "<CR>" },
    toggle_mode = { "<Tab>" },
    next_category = { "]" },
    prev_category = { "[" },
    page_down = { "J" },         -- move down by scroll_step rows
    page_up = { "K" },           -- move up by scroll_step rows
    line_home = { "H" },         -- jump to the first cell on the current row
    line_end = { "L" },          -- jump to the last cell on the current row
    search = { "/" },            -- open telescope fuzzy search (no-op if telescope absent)
  },
  default_insert_mode = "emoji", -- "emoji" | "shortcode"
  cell_width = 4,                -- display columns reserved per emoji in the grid
  scroll_step = 3,               -- rows moved per J/K (page_down/page_up)
})
```

Any keymap may be given as a single string or a list of strings.

## Emoji data

`lua/emj_picker/data/emojis.lua` is generated from `scripts/emoji-test.txt`
(a copy of the official Unicode emoji list). It is an ordered hierarchy that
preserves the official Unicode ordering:

```lua
return {
  { group = "Smileys & Emotion", subgroups = {
    { subgroup = "face-smiling", emojis = {
      { emoji = "😀", shortcode = "grinning_face" },
      -- ...
    } },
  } },
  -- ...
}
```

Each emoji entry carries only `emoji` and `shortcode` (the shortcode is the
Unicode name slugified, e.g. `red heart` → `red_heart`).

Skin-tone modifiers (U+1F3FB–1F3FF) and ZWJ sequences (U+200D) are **excluded**,
since their rendered width is terminal-dependent and breaks the grid alignment.
This yields 1674 emojis across the 9 Unicode groups.

To add more fields (descriptions, keywords, etc.), extend
`scripts/generate.lua` and regenerate:

```sh
nvim --headless -l scripts/generate.lua
```

## Nerd Font data

`lua/emj_picker/data/nerdfonts.lua` is generated from `scripts/glyphnames.json`
(the canonical Nerd Fonts glyph list). The dataset mirrors the emoji shape so
the grid UI can consume both, with each group being an icon set and a single
subgroup per group:

```lua
return {
  { group = "md", subgroups = {
    { subgroup = "md", glyphs = {
      { glyph = "󰀃", name = "md-access_point" },
      -- ...
    } },
  } },
  -- ...
}
```

Groups are ordered largest-first (Material Design is by far the biggest set).
Entries carry only `glyph` and `name`. Regenerate after updating
`scripts/glyphnames.json`:

```sh
nvim --headless -l scripts/generate_nerd.lua
```

## Credits

- Emoji data: [Unicode emoji-test.txt](https://unicode.org/Public/emoji/latest/emoji-test.txt)
- UI design inspired by [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Original inspiration: [icon-picker.nvim](https://github.com/ziontee113/icon-picker.nvim)

## License

MIT
