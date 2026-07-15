{
  description = "Burenix backup and restore system for nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    test-vm = {
      url = "github:jimurrito/nixos-test-vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  #
  outputs =
    {
      self,
      nixpkgs,
      test-vm,
      ...
    }:
    {
      #
      #
      #
      nixosModules.default.imports = [
        ./src/options.nix
        ./src/config.nix
      ];
      #
      #
      #
      #
      # TestVM
      nixosConfigurations = {
        #
        test-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import test-vm.baselineConfig { })
            self.nixosModules.default
            # test config
            {
              users.users.user.extraGroups = [ "burenix" ];
              services.burenix = {
                enable = true;
                keyPath = "/etc/hostname";
                backups =
                  let
                    # base backup datasource
                    conf = {
                      enable = true;
                      sourceDirs = [ "/etc/fstab" ];
                      targetDirs = [
                        "/var/burenix-backup"
                        "/opt/burenix-backup"
                      ];
                      backupTime = "Tue, 03:00:00";
                      rollover.enable = true;
                    };
                  in
                  {
                    # encrypted and non-encrypted versions
                    fstab = conf // {
                      checksum = true;
                    };
                    fstab_encrypted = conf // {
                      encryption.enable = true;
                    };
                  };
              };
            }
          ];
        };
      };
      #
      #
    };
  #
}
