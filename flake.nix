{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    obelisk = {
      url = "github:obeli-sk/obelisk/latest-rc";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        rust-overlay.follows = "rust-overlay";
      };
    };
  };

  outputs = { nixpkgs, flake-utils, obelisk, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            curl
            nodejs
            jq
            just
            socat
            obelisk.packages.${system}.default
            gh # scripts/sync-branch-protection.sh
            yq-go # scripts/sync-branch-protection.sh
            imagemagick # scripts/screenshots.sh
            python3Packages.vncdotool # scripts/screenshots.sh
            docker
            # activity-vm
            qemu # activity VM backend
            erofs-utils # Firecracker activity VM store images
            firecracker # Firecracker activity VM runtime
          ];
        };
      });
}
