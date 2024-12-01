{
  description = "MicroVM Jellyfin";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    sops-nix.url = "github:Mic92/sops-nix";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm, ... } @ inputs:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = {
        default = self.packages.${system}.vm-jellyfin;
        vm-jellyfin = self.nixosConfigurations.vm-jellyfin.config.microvm.declaredRunner;
      };

      nixosConfigurations = {

        vm-jellyfin = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ./guest.nix
          ];
        };
      };
    };
}
