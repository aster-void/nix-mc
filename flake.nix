{
  description = "NixOS modules for Minecraft servers (Forge, NeoForge, Bedrock)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.nix-mc = import ./nixosModules/nix-mc.nix;
    
    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        nix-mc-cli = pkgs.callPackage ./packages/nix-mc-cli { };
        default = self.packages.${system}.nix-mc-cli;
      });
  };
}
