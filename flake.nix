{
  description = "nreviewer — Neovim plugin and agent command for local branch code reviews";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      version = "0.0.1" + lib.optionalString (self ? shortRev) "-${self.shortRev}";

      nreviewerFor = pkgs: pkgs.callPackage ./nix/package.nix { inherit version; };
    in
    {
      overlays.default = final: _prev: {
        nreviewer = nreviewerFor final;
      };

      packages = forAllSystems (
        pkgs:
        let
          nreviewer = nreviewerFor pkgs;
        in
        {
          inherit nreviewer;
          default = nreviewer;
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.neovim
            pkgs.lua-language-server
            pkgs.stylua
            pkgs.git
          ];
        };
      });

      checks = forAllSystems (
        pkgs:
        let
          nreviewer = nreviewerFor pkgs;
        in
        {
          build = nreviewer;

          # Loads the plugin in a headless Neovim and calls setup(), which
          # catches syntax errors and any API that went away underneath us.
          plugin-loads =
            pkgs.runCommand "nreviewer-plugin-loads"
              {
                nativeBuildInputs = [ pkgs.neovim ];
              }
              ''
                export HOME=$TMPDIR
                nvim --headless --clean \
                  --cmd 'set runtimepath^=${nreviewer}' \
                  -c 'lua require("review-browser").setup()' \
                  -c 'lua assert(vim.fn.exists(":ReviewBrowse") == 2, "ReviewBrowse not defined")' \
                  -c 'quitall!'
                test -f ${nreviewer}/${nreviewer.commandFile}
                touch $out
              '';
        }
      );

      homeManagerModules.default = import ./nix/hm-module.nix self;

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
