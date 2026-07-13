{
  description = "NVIDIA ICAT (image/video comparison tool) repackaged natively for Linux/NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          # ICAT проприетарный — разрешаем unfree внутри флейка,
          # чтобы потребителям не приходилось настраивать это у себя
          config.allowUnfree = true;
        }));
    in
    {
      packages = forAllSystems (pkgs: rec {
        icat = pkgs.callPackage ./pkgs/icat.nix { };
        default = icat;
      });

      overlays.default = final: prev: {
        icat = final.callPackage ./pkgs/icat.nix { };
      };

      # nix run .#update — проверка новой версии по фиду автообновлятора NVIDIA
      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = pkgs.lib.getExe (pkgs.writeShellApplication {
            name = "nix-icat-update";
            runtimeInputs = [ pkgs.curl pkgs.jq ];
            text = builtins.readFile ./scripts/update.sh;
          });
        };
      });
    };
}
