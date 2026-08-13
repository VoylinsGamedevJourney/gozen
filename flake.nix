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
        devShells.default =
          let
            gde_gozen = (self'.packages.gde_gozen.override { target = "debug"; });
          in
          pkgs.mkShell {
            nativeBuildInputs = [ pkgs.godot_4_7 ];
            buildInputs = [ gde_gozen ];

            shellHook = ''
              mkdir -p ./bin
              cp -r --no-preserve=mode ${gde_gozen}/lib/* ./bin
              chmod +w ./bin ./bin/**/*
            '';
          };

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
