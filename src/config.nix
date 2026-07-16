{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  burenix-nixops = config.services.burenix;
  backups = burenix-nixops.backups;
  #
  # Backup obj unwrapper
  buMapper =
    logic:
    (mkMerge (mapAttrsToList (buName: buConf: (mkIf buConf.enable (logic buName buConf))) backups));
  #
  #
in
{
  #
  #
  imports = [
    ./cli.nix
  ];
  #
  #
  # config to be implemented via the `options`
  config = mkIf (burenix-nixops.enable) {
    #
    # Group for burenix
    users.groups.burenix = { };
    #
    #
    environment = {
      # Ensures jq is available
      systemPackages = [ pkgs.jq ];
      # maps out backup declarations
      etc = buMapper (
        buName: buConf:
        let
          # determines keypath
          buKeyPath = optionalString (buConf.encryption.enable) buConf.encryption.keyPath;
        in
        {
          #
          # easily accessible configs for the burenix-cli
          "burenix/conf/${buName}.json" = {
            # readable only by owner and group for the backup
            mode = "0440";
            user = buConf.user;
            group = buConf.group;
            text = toJSON {
              name = buName;
              sources = buConf.sourceDirs;
              temp = buConf.tempDir;
              targets = buConf.targetDirs;
              preRunScript = (mkIf (buConf.preRunScript.enable) buConf.preRunScript).content;
              postRunScript = (mkIf (buConf.postRunScript.enable) buConf.postRunScript).content;
              rollover = buConf.rollover;
              backupTime = buConf.backupTime;
              useSSH = buConf.useSSH;
              usePigz = buConf.usePigz;
              keyPath = buKeyPath;
              checksum = buConf.checksum;
            };
          };
        }
      );
    };
    #
    #
    # systemd service
    systemd =
      let
        srvDeps = with pkgs; [
          gnutar
          bash
          gzip
          pigz
          openssh # for scp
          gnupg # for gpg
        ];
        # pre/post script
        mkScript =
          scriptConf:
          (mkIf (scriptConf.enable) ''
            ${getExe pkgs.bash} ${scriptConf.file} ${scriptConf.arguments}
          '');
        # job scripts
        mkScriptExe =
          name: script:
          (pkgs.runCommand name { } ''
            cp ${script} $out
            chmod 0555 $out
          '');
        backup-job = mkScriptExe "backup-job" ./jobs/backup.bash;
        restore-job = mkScriptExe "restore-job" ./jobs/restore.bash;
      in
      # maps out backup declarations
      buMapper (
        buName: buConf:
        let
          # determines keypath
          buKeyPath = optionalString (buConf.encryption.enable) buConf.encryption.keyPath;
        in
        {
          #
          #
          # Backup Service
          services."burenix-${buName}-backup" = {
            enable = true;
            description = "Burenix backup job for data source [${buName}]";
            path = srvDeps;
            serviceConfig = {
              Type = "oneshot";
              User = buConf.user;
              Group = buConf.group;
              # Pre-Execution script for the buConf
              ExecStartPre = mkScript buConf.preRunScript;
              # ExecStart runs after all ExecStartPre commands have finished successfully
              ExecStart =
                let
                  job-args = join " " [
                    "-n ${buName}"
                    "-d ${(join " -d " buConf.sourceDirs)}"
                    "-t ${(join " -t " buConf.targetDirs)}"
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.rollover.enable) "-r ${toString buConf.rollover.intervalDays}")
                    (optionalString (buConf.encryption.enable) "-k ${buKeyPath}")
                    (optionalString (buConf.checksum) "-v")
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                  ];
                in
                ''
                  ${backup-job} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost = mkScript buConf.postRunScript;
            };
          };
          # backup service timer
          timers."burenix-${buName}-backup" = mkIf (isString buConf.backupTime) {
            enable = true;
            description = "Triggers backup for data source [${buName}] @ [${buConf.backupTime}]";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = buConf.backupTime;
            };
          };
          #
          #
          # Backup data source init
          services."burenix-${buName}-init" =
            let
              script = ''
                #!/usr/bin/env bash
                # Makes destination directories
                ${pkgs.coreutils}/bin/mkdir -p ${(join " " buConf.targetDirs)}
                ${pkgs.coreutils}/bin/chown -Rv ${buConf.user}:${buConf.group} ${(join " " buConf.targetDirs)}
              '';
              exe = pkgs.runCommand "${buName}-init" { } ''
                echo -e "${script}" > $out
                chmod 0555 $out
              '';
            in
            {
              enable = true;
              description = "Target creator for Buenix backup [${buName}]";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              path = with pkgs; [
                coreutils
                bash
              ];
              serviceConfig = {
                User = "root";
                Group = "root";
                Type = "oneshot";
                ExecStart = ''
                  ${exe}
                '';
              };
            };
          #
          #
          # Backup restore service(s)
          services."burenix-${buName}-restore" = {
            enable = true;
            description = "Burenix restore job for data source [${buName}]";
            path = srvDeps;
            serviceConfig = {
              Type = "oneshot";
              User = buConf.user;
              Group = buConf.group;
              # Pre-Execution script for the buConf
              ExecStartPre = mkScript buConf.preRunScript;
              # ExecStart runs after all ExecStartPre commands have finished successfully
              ExecStart =
                let
                  job-args = join " " [
                    "-n ${buName}"
                    # grabs the first target as it is primary for automatic restores
                    "-t ${elemAt buConf.targetDirs 0}"
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.encryption.enable) "-k ${buKeyPath}")
                    (optionalString (buConf.checksum) "-v")
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                  ];
                in
                ''
                  ${restore-job} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost = mkScript buConf.postRunScript;
            };
          };
        }
      );
  };
}
