{
  description = "Burenix backup and restore system for nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  #
  outputs =
    { ... }:
    let
      #system = "x86_64-linux";
      #pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      #
      # <PACKAGE + service via Options>
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          burenix-nixops = config.services.burenix;
        in
        with lib;
        {
          #
          #
          # Options for services overlay
          options.services.burenix = {
            default = { };
            enable = mkEnableOption "The burenix module entirely";
            # Compression Key file path
            keyPath = mkOption {
              type = types.str;
              default = "/root/backup-key";
              description = "Key used to encrypt the compressed files.";
            };
            # Backup definitions
            # Each definition is considered a ''data source''
            backups = mkOption {
              type = types.attrsOf (
                types.submodule (
                  { ... }:
                  {
                    # Options per backup instance defined
                    options = {
                      #
                      enable = mkEnableOption "The backup of this data source";
                      # User the service will run under
                      user = mkOption {
                        type = types.str;
                        default = "root";
                        description = "System user to run the backup service under. Defaults to root due to complex permissions needed.";
                      };
                      # The group this service should run under
                      group = mkOption {
                        type = types.str;
                        default = "root";
                        description = "Group for the service.";
                      };
                      sourceDirs = mkOption {
                        type = types.listOf types.str;
                        default = [ ];
                        description = "Path(s) to the target data that needs to be backed up.";
                      };
                      tempDir = mkOption {
                        type = types.str;
                        default = "/tmp";
                        description = "Temporary directory used when compressing the backup.";
                      };
                      targetDirs = mkOption {
                        type = types.listOf types.str;
                        default = [ ];
                        description = "List of target paths to backup the data to. If set to an empty list, no backup will be done.";
                      };
                      rolloverIntervalDays = mkOption {
                        type = types.number;
                        default = 14;
                        description = "Defines the age a backup needs to be, before it is pruned. Defaults to 14 (days).";
                      };
                      backupTime = mkOption {
                        type = types.str;
                        default = "Tue, 4:00:00";
                        description = "Time the backup will trigger. Defaults to 'Tue, 4:00:00'. Uses Systemd Timer formatting.";
                      };
                      useSSH = mkOption {
                        type = types.bool;
                        default = false;
                        description = "If toggled, scp will be used for the backup transfers.";
                      };
                      usePigz = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Toggles the use of Pigz (multi-threaded gzip) when compressing the archive. Pigz will use all cores and memory available.";
                      };
                      noEncrypt = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Disables encryption of the backup file.";
                      };
                      preRunScript = {
                        default = { };
                        enable = mkEnableOption "the use of this pre-run backup script.";
                        source = mkOption {
                          type = types.path;
                          default = null;
                          description = "Path to the script that will be used.";
                        };
                        arguments = mkOption {
                          type = types.str;
                          default = "";
                          description = "Arguments that will be taken by the script.";
                        };
                      };
                      postRunScript = {
                        default = { };
                        enable = mkEnableOption "Toggles the use of this post-run backup script.";
                        source = mkOption {
                          type = types.path;
                          default = null;
                          description = "Path to the script that will be used.";
                        };
                        arguments = mkOption {
                          type = types.str;
                          default = "";
                          description = "Arguments that will be taken by the script.";
                        };
                      };
                    };
                  }
                )
              );
              default = { };
              description = "Data source configurations.";
            };
            #
          };
          #
          #
          # config to be implemented via the `options`
          config = mkIf (burenix-nixops.enable) {
            #
            imports = [
              ./cli.nix
            ];
            #
            environment = {
              # Imports package and runs the install steps
              systemPackages = [
                pkgs.pigz
              ];
              #
              # easily accessible configs/scripts for the datasources
              etc = mkMerge (
                mapAttrsToList (
                  name: dataSource:
                  mkIf (dataSource.enable) {
                    # data source source-paths
                    "burenix/conf/${name}.src.conf" = {
                      enable = dataSource.enable;
                      mode = "0444";
                      text = concatStringsSep " " dataSource.sourceDirs;
                    };
                    # temp destination
                    "burenix/conf/${name}.tmp.conf" = {
                      enable = dataSource.enable;
                      mode = "0444";
                      text = dataSource.tempDir;
                    };
                    # data source destination-paths
                    "burenix/conf/${name}.tgt.conf" = {
                      enable = dataSource.enable;
                      mode = "0444";
                      text = concatStringsSep " " dataSource.targetDirs;
                    };
                  }
                ) burenix-nixops.backups
              );
            };
            #
            # Burenix CLI
            services.burenix-cli = {
              enable = true;
              keyPath = burenix-nixops.keyPath;
            };
            #
            # systemd service
            systemd =
              let
                bash = getExe pkgs.bash;
              in
              mkMerge (
                mapAttrsToList (
                  name: dataSource:
                  mkIf (dataSource.enable) {
                    # Data source systemd service
                    services."backup-${name}" = {
                      enable = true;
                      description = "Burenix backup job for data source [${name}]";
                      restartIfChanged = true;
                      serviceConfig = {
                        Type = "oneshot";
                        User = dataSource.user;
                        Group = dataSource.group;
                        # Pre-Execution script for the datasource
                        ExecStartPre = optionalString (dataSource.preRunScript.enable) ''
                          ${bash} ${dataSource.preRunScript.source} ${dataSource.preRunScript.arguments}
                        '';
                        # ExecStart runs after all ExecStartPre commands have finished successfully
                        ExecStart = ''
                          ${bash} ${./backup-job.bash} \
                            -n ${name} \
                            -d "${(concatStringsSep " " dataSource.sourceDirs)}" \
                            -t "${(concatStringsSep " " dataSource.targetDirs)}" \
                            -r ${toString dataSource.rolloverIntervalDays} \
                            -k ${burenix-nixops.keyPath} \
                            -o ${dataSource.tempDir} \
                            ${optionalString (dataSource.usePigz) "-p"} \
                            ${optionalString (dataSource.useSSH) "-s"} \
                            ${optionalString (dataSource.noEncrypt) "-x"}
                        '';
                        # Ran after all 'ExecStart' commands have finished successfully.
                        ExecStartPost = optionalString (dataSource.postRunScript.enable) ''
                          ${bash} ${dataSource.preRunScript.source} ${dataSource.postRunScript.arguments}
                        '';
                      };
                      path = with pkgs; [
                        gnutar
                        gzip
                        pigz
                        openssh # for scp
                        gnupg # for gpg
                      ];
                    };
                    # data source systemd service timer
                    timers."backup-${name}" = {
                      enable = true;
                      description = "Triggers backup for data source [${name}] @ [${dataSource.backupTime}]";
                      wantedBy = [ "timers.target" ];
                      timerConfig = {
                        OnCalendar = dataSource.backupTime;
                      };
                    };
                    #
                  }
                ) burenix-nixops.backups
              );
            #
            #
          };
        };
    };
}
