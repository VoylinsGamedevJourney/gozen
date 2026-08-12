{
  description = "GoZen — The Minimalist Video Editor";

  inputs = {
    self.submodules = true;
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { pkgs, self', ... }: {
        packages = {
          gde_gozen = pkgs.callPackage ./gde_gozen.nix {
            version = "0-latest-${self.lastModifiedDate}-${self.shortRev or self.dirtyShortRev or "unknown"}";
          };
          gozen = pkgs.callPackage ./gozen.nix {
            gde_gozen = self'.packages.gde_gozen;
            version = "0-latest-${self.lastModifiedDate}-${self.shortRev or self.dirtyShortRev or "unknown"}";
          };
          default = self'.packages.gozen;
        };

        apps.default = {
          program = self'.packages.gozen;
          meta.description = self'.packages.gozen.meta.description;
        };
      };
    };
}
