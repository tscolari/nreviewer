{
  lib,
  vimUtils,
  version ? "0-unstable",
}:

vimUtils.buildVimPlugin {
  pname = "nreviewer";
  inherit version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../lua
      ../commands
    ];
  };

  # `commands/review-branch.md` is not part of the runtime plugin, but the
  # plugin resolves it relative to its own directory (see init.lua), and the
  # Home Manager module links it into the agent's command directory. Keeping it
  # in $out is what makes both work.
  passthru.commandFile = "commands/review-branch.md";

  meta = {
    description = "Neovim plugin and agent command for local branch code reviews";
    homepage = "https://github.com/tscolari/nreviewer";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
