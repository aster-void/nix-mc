# Test that module evaluation doesn't cause infinite recursion
let
  nixpkgs = import <nixpkgs> {};
  
  # Use nixosSystem to get a proper minimal NixOS config
  eval = (import <nixpkgs/nixos> {
    system = "x86_64-linux";
    configuration = {
      imports = [ ../nixosModules/nix-mc.nix ];
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
    };
  });
in
{
  # Test that we can evaluate all server configurations without infinite recursion
  forge-ports = eval.config.services.minecraft.servers.test.ports;
  bedrock-ports = eval.config.services.minecraft.servers.bedrock-test.ports;
  
  # Test that defaults are applied correctly
  forge-tcp-ports = eval.config.services.minecraft.servers.test.ports.tcp;
  bedrock-udp-ports = eval.config.services.minecraft.servers.bedrock-test.ports.udp;
  
  # Test systemd services are generated
  services = builtins.attrNames (nixpkgs.lib.filterAttrs (n: v: nixpkgs.lib.hasPrefix "minecraft-" n) eval.config.systemd.services);
}