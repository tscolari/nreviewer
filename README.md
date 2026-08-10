# nreviewer

A Neovim plugin and coding-agent slash command for local branch code reviews. Works with Claude Code and opencode.

## How it works

Opinionated around git worktrees — each worktree holds a single feature branch, so `.reviews/` files are always branch-specific without needing branch names in filenames.

The `/review-branch` command reviews your branch diff against its base branch — `main` or `master`, detected automatically — and writes the result to `.reviews/<datetime>.md`. The Neovim plugin lets you browse those files and jump from review references directly into the source code.

The review is multi-pass: four specialist reviewers (guidance-file compliance, bugs, security, and tests/performance) run in parallel, then every finding they produce is independently validated before it reaches the report, and unvalidated ones are discarded. That keeps false positives down at the cost of a noticeably slower and more token-hungry run than a single-pass review.

### Ticket context

On a branch shaped `<prefix>/<ticket>/<task>` — the layout [worktool](https://github.com/tscolari/worktool) creates — the ticket id is read off the branch name. If a notes MCP such as [obsidian-graph-mcp](https://github.com/tscolari/obsidian-graph-mcp) is connected, the command looks the ticket up there and passes what it finds to every reviewer as author intent, which keeps deliberate choices from being flagged as mistakes. It also lets the review flag requirements the ticket states but the branch never implements.

Entirely optional: with no notes MCP connected, or on a branch that doesn't match that shape, the step is skipped silently and the review runs on commit messages alone.

> Tip: add `.reviews/` to your global gitignore (`~/.gitignore_global`) so review files are never accidentally committed.

## Install

Two halves: the Neovim plugin, and the `review-branch.md` command file that your agent picks up. Install both.

### lazy.nvim

```lua
{
  url = "https://codeberg.org/tscolari/nreviewer",
  config = function()
    require("review-browser").setup()
  end,
}
```

Then, once, from Neovim:

```vim
:ReviewBranchInstall claude    " or: :ReviewBranchInstall opencode
```

That symlinks `commands/review-branch.md` out of the plugin's own install directory (resolved automatically, wherever lazy.nvim put it) into `~/.claude/commands/` or `~/.config/opencode/commands/`.

Optional keymap — `<leader>cy` (copy section) is set automatically inside review buffers:

```lua
vim.keymap.set("n", "<leader>cr", "<cmd>ReviewBrowse<cr>", { desc = "Browse code reviews" })
```

### Nix

The flake exposes the plugin as a package (`packages.default`), an overlay (`pkgs.nreviewer`), and a Home Manager module that places the command file for you — no `:ReviewBranchInstall` step.

```nix
{
  inputs.nreviewer.url = "github:tscolari/nreviewer";

  # Home Manager: installs review-branch.md for the agents you list.
  imports = [ inputs.nreviewer.homeManagerModules.default ];

  programs.nreviewer = {
    enable = true;
    agents = [ "claude" "opencode" ];   # default: [ "claude" ]
  };
}
```

The package is an ordinary vim plugin derivation, so the Neovim half is wired up wherever your plugins are declared:

```nix
extraPlugins = [ pkgs.nreviewer ];          # nixvim
programs.neovim.plugins = [ pkgs.nreviewer ];  # Home Manager's neovim module
```

Either apply `inputs.nreviewer.overlays.default` for `pkgs.nreviewer`, or use `inputs.nreviewer.packages.${system}.default` directly.

| Option | Default | Description |
|--------|---------|-------------|
| `programs.nreviewer.enable` | `false` | Install the command file |
| `programs.nreviewer.package` | this flake's package | Package to take `review-branch.md` from |
| `programs.nreviewer.agents` | `[ "claude" ]` | Any of `claude` (`~/.claude/commands`), `opencode` (`~/.config/opencode/commands`) |
| `programs.nreviewer.extraCommandDirs` | `[ ]` | Extra `$HOME`-relative directories for agents not covered above |

Also available: `nix build` / `nix flake check` (headless-Neovim load check), a `devShells.default` with neovim, lua-language-server and stylua, and `nix fmt`.

## Usage

1. In a Claude Code or opencode session, run `/review-branch` — the branch is diffed against `main`/`master` and the review is written to `.reviews/<datetime>.md`. Expect it to take a while; it fans out to parallel reviewers and then validates each finding.
2. In Neovim, run `:ReviewBrowse` — select a review to open it full screen
3. Inside the review:
   - `gf` — open the nearest file reference above cursor in a right vsplit
   - `gF` — open the nearest file reference above cursor in the current window

`gf`/`gF` search backwards from the cursor, so they work anywhere within a file's section — not just on the filename line itself.

## Commands

| Command | Description |
|---------|-------------|
| `:ReviewBrowse` | Date-sorted picker of `.reviews/*.md`, opens selected full screen |
| `:ReviewOpen` | Open nearest file reference above cursor in current window |
| `:ReviewOpenSplit` | Open nearest file reference above cursor in a right vsplit |
| `:ReviewCopySection` | Copy current file section (header → `---`) to system clipboard |
| `:ReviewBranchInstall <target>` | Symlink the review command for `claude` or `opencode` |

`:ReviewOpen`, `:ReviewOpenSplit`, and `:ReviewCopySection` are buffer-local — available only inside `.reviews/*.md` files.

## Default keymaps

Set automatically inside review buffers. Override by mapping to the commands above.

| Key | Command |
|-----|---------|
| `gf` | `:ReviewOpenSplit` |
| `gF` | `:ReviewOpen` |
| `<leader>cy` | `:ReviewCopySection` |
