{
  lib,
  pkgs,
  ...
}:
with lib;
{
  config = {
    environment = {
      shellAliases = {
        burenix-cli = pkgs.runCommand "burenix-cli" { } ''
          cp ${./cli_entrypoint.bash} $out
          chmod 0555 $out
        '';
      };
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
            "show"
            "logs"
          ]
      );
    };
  };
  #
}
