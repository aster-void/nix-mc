{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = _: {
    nixosModules.nix-mc = import ./nixosModules/nix-mc.nix;
  };
}
