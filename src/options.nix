{ lib, ... }:
with lib;
let
  # creates sub module options for a dynamic option
  mkDynSubmod =
    mod:
    types.attrsOf (
      types.submodule {
        options = mod;
      }
    );
  # creates sub module options for a static option
  mkSubmod =
    mod:
    types.submodule {
      options = mod;
    };
in
{
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
      description = "An individual backup declaration";
      type = mkDynSubmod {
        enable = mkEnableOption "The backup of this data source";
        user = mkOption {
          type = types.str;
          default = "root";
          description = "System user to run the backup service under. Defaults to root due to complex permissions needed.";
        };
        group = mkOption {
          type = types.str;
          default = "burenix";
          description = "Group for the service.";
        };
        #
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
        #
        preRunScript = mkOption {
          default = { };
          description = "Script that will be ran prior to the backup/restore has started.";
          type = mkSubmod {
            enable = mkEnableOption "the use of this pre-run backup script.";
            file = mkOption {
              type = types.nullOr types.path;
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
        postRunScript = mkOption {
          default = { };
          description = "Script that will be ran after the backup/restore has completed";
          type = mkSubmod {
            enable = mkEnableOption "Toggles the use of this post-run backup script.";
            file = mkOption {
              type = types.nullOr types.path;
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
        #
        rollover = mkOption {
          description = "Optional rollover of old archives within the target directories.";
          type = mkSubmod {
            enable = mkEnableOption "Rollover of existing backupfiles";
            intervalDays = mkOption {
              type = types.number;
              default = 14;
              description = "Defines the age, in days, a backup needs to be before it is pruned. Defaults to (14) days.";
            };
          };
        };
        backupTime = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Time the backup will trigger. Defaults to null meaning disabled. Uses Systemd Timer formatting.";
        };
        useSSH = mkEnableOption "scp will be used for the backup transfers.";
        usePigz = mkEnableOption "Toggles the use of Pigz (multi-threaded gzip) when compressing the archive. Pigz will use all cores and memory available.";
        encryption = mkOption {
          description = "Uses `gpg` for encryption and integrity checks.";
          type = mkSubmod {
            enable = mkEnableOption "enables use of gpg";
            keyPath = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Overrides the encryption 'keyPath' set in the parent configuration.";
            };
          };
        };
        checksum = mkEnableOption "Enables use of checksum validation. Uses for sha256 for non-encrypted backups. GPG for encrypted ones.";
      };
    };
  };
}
