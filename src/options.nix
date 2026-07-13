{ lib, ... }:
with lib;
let
  mkSubOption =
    mod:
    with types;
    mkOption {
      type = attrsOf (submodule ({ ... }: { options = mod; }));
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
    backups =
      mkSubOption
        # Options per backup instance defined
        {
          default = { };
          description = "Data source configurations.";
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
          keyPathOverride = mkOption {
            type = types.str;
            default = "";
            description = "Overrides the encryption 'keyPath' set in the parent configuration.";
          };
          preRunScript = mkSubOption {
            # mkSubOption
            default = { };
            enable = mkEnableOption "the use of this pre-run backup script.";
            file = mkOption {
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
          postRunScript = mkSubOption {
            default = { };
            enable = mkEnableOption "Toggles the use of this post-run backup script.";
            file = mkOption {
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
  };
}
