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
    
    nixosConfigurations.test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.nix-mc
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "/dev/null"; fsType = "tmpfs"; };
          services.minecraft = {
            enable = true;
            servers.test = {
              type = "forge";
            };
            servers.bedrock-test = {
              type = "bedrock";
            };
          };
          system.stateVersion = "25.11";
        }
      ];
    };
  };
}
