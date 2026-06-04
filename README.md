# nreviewer

A Neovim plugin and Claude Code slash command for local branch code reviews.

## How it works

Opinionated around git worktrees — each worktree holds a single feature branch, so `.reviews/` files are always branch-specific without needing branch names in filenames.

The `/review-branch` Claude Code command reviews your branch diff against `main` and writes the result to `.reviews/<datetime>.md`. The Neovim plugin lets you browse those files and jump from review references directly into the source code.

> Tip: add `.reviews/` to your global gitignore (`~/.gitignore_global`) so review files are never accidentally committed.

## Install

### Neovim plugin — lazy.nvim

```lua
{
  url = "https://codeberg.org/tscolari/nreviewer",
  config = function()
    require("review-browser").setup()
  end,
}
```

Optional keymap:

```lua
vim.keymap.set("n", "<leader>cr", "<cmd>ReviewBrowse<cr>", { desc = "Browse code reviews" })
```

### Claude Code command

After installing the plugin, run this once from Neovim:

```vim
:ReviewBranchInstall claude
```

This symlinks `commands/review-branch.md` from the plugin's install directory into `~/.claude/commands/`.

Adjust the source path to match your lazy.nvim install directory if different.

## Usage

1. In a Claude Code session, run `/review-branch` — the review is written to `.reviews/<datetime>.md`
2. In Neovim, run `:ReviewBrowse` — select a review to open it full screen
3. Inside the review:
   - `gf` — open the nearest file reference above cursor in a right vsplit
   - `gF` — open the nearest file reference above cursor in the current window

`gf`/`gF` search backwards from the cursor, so they work anywhere within a file's section — not just on the filename line itself.

## Features

- `:ReviewBrowse` — date-sorted picker of `.reviews/*.md`, opens selected full screen
- `gf` — opens file reference in a right vsplit
- `gF` — opens file reference in the current window
- Line wrapping enabled automatically in review buffers
- No external dependencies
