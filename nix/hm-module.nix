self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nreviewer;

  # Mirrors the `installers` table in lua/review-browser/init.lua, so that
  # `:ReviewBranchInstall <agent>` and this module land the file in the same
  # place. Paths are relative to $HOME.
  agentDirs = {
    claude = ".claude/commands";
    opencode = ".opencode/commands";
  };

  commandSource = "${cfg.package}/${cfg.package.commandFile}";

  linksFor = dir: {
    name = "${dir}/review-branch.md";
    value.source = commandSource;
  };
in
{
  options.programs.nreviewer = {
    enable = lib.mkEnableOption "nreviewer, a Neovim branch-review browser";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "nreviewer.packages.\${system}.default";
      description = ''
        The nreviewer package. Installing it here only places the
        `review-branch` command file; the Neovim plugin itself has to be added
        to your Neovim configuration (`extraPlugins` under nixvim,
        `programs.neovim.plugins` otherwise) using this same package.
      '';
    };

    agents = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames agentDirs));
      default = [ "claude" ];
      example = [
        "claude"
        "opencode"
      ];
      description = ''
        Agents to install `review-branch.md` for. Replaces the manual
        `:ReviewBranchInstall <agent>` step: `claude` writes
        `~/.claude/commands/review-branch.md`, `opencode` writes
        `~/.opencode/commands/review-branch.md`.
      '';
    };

    extraCommandDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ ".config/some-agent/commands" ];
      description = ''
        Escape hatch for agents not covered by `agents`. Each entry is a
        $HOME-relative directory that `review-branch.md` is linked into.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.listToAttrs (
      map linksFor ((map (agent: agentDirs.${agent}) cfg.agents) ++ cfg.extraCommandDirs)
    );
  };
}
