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
            docker
            jq
            just
            nodejs_22
            playwright-driver
            socat
            obelisk.packages.${system}.default
          ];
          shellHook = ''
            export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=$(echo ${pkgs.playwright-driver.browsers}/chromium-*/chrome-linux*/chrome)
          '';
        };
      });
}
