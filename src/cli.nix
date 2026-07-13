{
  config,
  lib,
  pkgs,
  ...
}:
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
    in
    mkIf (cli-nixops.enable) {
      #
      environment = {
        shellAliases =
          let
            script = pkgs.runCommand "burenix-cli" { } ''
              cp ${./cli_entrypoint.bash} $out
              chmod 0555 $out
            '';
          in
          {
            burenix-cli = "${script} ${cli-nixops.keyPath}";
          };
        #
        # Imports all the cli sub-command scripts
        etc = mkMerge (
          map
            (cmd: {
              "burenix/cli/${cmd}" = {
                enable = true;
                mode = "0555";
                source = ./cli/${cmd}.bash;
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
