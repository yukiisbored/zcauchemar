{
  description = "Stack-based programming language which emulates the look and feel of the 60s";

  inputs = {
    utils.url = "github:numtide/flake-utils";
    gitignore.url = "github:hercules-ci/gitignore.nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig";
      };
    };
  };

  outputs = { self, utils, gitignore, nixpkgs, zig, zls }: 
    utils.lib.eachDefaultSystem (system:
      let
        inherit (gitignore.lib) gitignoreSource;

        pkgs = import nixpkgs { 
          inherit system;
          overlays = [
            zig.overlays.default
            (self: super: {
              inherit (zls.packages.${self.system}) zls;
            })
          ];
        };
      in
      {
        packages = rec {
          zcauchemar = pkgs.stdenvNoCC.mkDerivation {
            name = "zcauchemar";
            version = "main";
            src = gitignoreSource ./.;
            nativeBuildInputs = [ pkgs.zigpkgs.master ];
            dontConfigure = true;
            dontInstall = true;
            buildPhase = ''
              mkdir -p $out
              mkdir -p .cache/{p,z,tmp}
              zig build install --cache-dir $(pwd)/zig-cache --global-cache-dir $(pwd)/.cache -Dcpu=baseline -Doptimize=ReleaseSafe --prefix $out
            '';
          };

          default = zcauchemar;
        };
      }
    );
}
