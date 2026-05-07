{ config, lib, pkgs, ... }:
with lib;
{
  #
  # Imports and configures the CLI
  options.services.burenix-cli = {
    default = { };
    enable = mkEnableOption "The burenix CLI";
    keyPath = mkOption {
      type = types.str;
      default = "/root/backup-key";
      description = "Key used to encrypt the compressed files.";
    };
  };
  #
  #
  config =
    let
      cli-nixops = config.services.burenix-cli;
      bash = getExe pkgs.bash;
    in
    mkIf (cli-nixops.enable) {
      #
      environment = {
        #
        shellAliases = {
          # have to execute in bash as file imported using types.path only have read only file modes.
          burenix-cli = "${bash} ${./cli_entrypoint.bash} ${cli-nixops.keyPath}";
        };
        #
        # Imports all the cli sub-command scripts
        etc = mkMerge (
          map
            (s: {
              "burenix/cli/${s}.bash" = {
                enable = true;
                mode = "0555";
                source = ./cli/${s}.bash;
              };
            })
            [
              "help"
              "ls"
              "backup"
              "restore"
            ]
        );
        #
      };
      #
      #
    };
  #
}
