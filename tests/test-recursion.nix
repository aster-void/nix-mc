# Test that module evaluation doesn't cause infinite recursion
let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  
  # Evaluate the module in the NixOS module system
  eval = lib.evalModules {
    modules = [
      ./nixosModules/nix-mc.nix
      {
        services.minecraft = {
          enable = true;
          servers.test = {
            type = "forge";
            upstreamDir = /tmp;
          };
          servers.bedrock-test = {
            type = "bedrock";
            upstreamDir = /tmp;
          };
        };
      }
    ];
  };
in
{
  # Test that we can evaluate all server configurations without infinite recursion
  forge-ports = eval.config.services.minecraft.servers.test.ports;
  bedrock-ports = eval.config.services.minecraft.servers.bedrock-test.ports;
  
  # Test systemd services are generated correctly
  services = builtins.attrNames eval.config.systemd.services;
}