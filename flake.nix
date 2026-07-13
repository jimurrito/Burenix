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
        ./src/cli.nix
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
            (
              { pkgs, ... }:
              {
                environment.systemPackages = [ pkgs.jq ];
                #
                services.burenix = {
                  enable = true;
                  keyPath = "/etc/hostname";
                  backups =
                    let
                      # base backup datasource
                      conf = {
                        enable = true;
                        sourceDirs = [ "/home/user/test.file" ];
                        targetDirs = [
                          "/var/burenix-backup"
                        ];
                        backupTime = "Tue, 03:00:00";
                      };
                    in
                    {
                      # encrypted and non-encrypted versions
                      varlog_encrypted = conf;
                      varlog = conf // {
                        noEncrypt = true;
                      };
                    };
                };
              }
            )
          ];
        };
      };
      #
      #
    };
  #
}
