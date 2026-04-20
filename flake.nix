{
  description = "kak-tree-sitter + helix";

  inputs = {
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    helix = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      helix,
      ...
    }:
    let
      lib = nixpkgs.lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forAllSystems =
        f:
        lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = nixpkgs.legacyPackages.${system};
            inherit system;
          }
        );
    in
    {
      overlays.default = final: prev: {
        kak-tree-sitter = import ./nix {
          pkgs = prev;
          inherit helix;
        };
      };

      packages = forAllSystems (
        { pkgs, ... }:
        let
          kak-tree-sitter = import ./nix { inherit pkgs helix; };

          kak-tree-sitter-themes = pkgs.callPackage (import ./nix/gen-themes.nix { inherit helix; }) { };
        in
        {
          default = kak-tree-sitter;
          themes = kak-tree-sitter-themes;
        }
      );

      apps = forAllSystems (
        { pkgs, ... }:
        let
          kak-tree-sitter = import ./nix { inherit pkgs helix; };
        in
        {
          default = {
            type = "app";
            program = "${kak-tree-sitter}/bin/kak-tree-sitter";
          };
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);

      homeManagerModules.kak-tree-sitter-helix =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          kak-tree-sitter = import ./nix { inherit pkgs helix; };

          kak-tree-sitter-themes = pkgs.callPackage (import ./nix/gen-themes.nix { inherit helix; }) { };
        in
        {
          options.programs.kak-tree-sitter-helix.enable = lib.mkEnableOption "Enable kak-tree-sitter-helix";

          config = lib.mkIf config.programs.kak-tree-sitter-helix.enable {
            home.packages = [ kak-tree-sitter ];

            xdg.configFile."kak/colors/kak-tree-sitter-helix".source = "${kak-tree-sitter-themes}/colors";
          };
        };

      nixosModules.kak-tree-sitter-helix =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.kak-tree-sitter-helix;

          kak-tree-sitter = import ./nix { inherit pkgs helix; };

          kak-tree-sitter-themes = pkgs.callPackage (import ./nix/gen-themes.nix { inherit helix; }) { };
        in
        {
          options.programs.kak-tree-sitter-helix = {
            enable = lib.mkEnableOption "Enable kak-tree-sitter-helix";

            user = lib.mkOption {
              type = lib.types.str;
              description = "User to install Kakoune themes for";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ kak-tree-sitter ];

            systemd.user.tmpfiles.users.${cfg.user}.rules = [
              "L+ /home/${cfg.user}/.config/kak/colors/kak-tree-sitter-helix 0444 - - - ${kak-tree-sitter-themes}/colors"
            ];
          };
        };
    };
}
