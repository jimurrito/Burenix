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
  mkKeyPath = i: (if (i != "") then i else burenix-nixops.keyPath);
  #
  #
in
{
  #
  #
  # config to be implemented via the `options`
  config = mkIf (burenix-nixops.enable) {
    #
    # Burenix CLI
    services.burenix-cli = {
      enable = true;
      keyPath = burenix-nixops.keyPath;
    };
    #
    #
    environment = {
      etc = buMapper (
        buName: buConf:
        let
          # determines keypath
          buKeyPath = mkKeyPath buConf.keyPathOverride;
        in
        {
          #
          # easily accessible configs for the burenix-cli
          "burenix/conf/${buName}.json" =
            let
              ifEmpty = i: (if (i != { }) then i else { });
            in
            {
              mode = "0444";
              text = toJSON {
                keyPath = buKeyPath;
                sources = buConf.sourceDirs;
                temp = buConf.tempDir;
                targets = buConf.targetDirs;
                useSSH = buConf.useSSH;
                usePigz = buConf.usePigz;
                noEncrypt = buConf.noEncrypt;
                preRunScript = ifEmpty buConf.preRunScript;
                postRunScript = ifEmpty buConf.postRunScript;
                rolloverIntervalDays = buConf.rolloverIntervalDays;
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
        bash = getExe pkgs.bash;
        srvDeps = with pkgs; [
          gnutar
          gzip
          pigz
          openssh # for scp
          gnupg # for gpg
        ];
        #
        backup-job = pkgs.runCommand "burenix-backup" { } ''
          cp ${./jobs/backup.bash} $out
          chmod 0555 $out
        '';
        restore-job = pkgs.runCommand "burenix-restore" { } ''
          cp ${./jobs/restore.bash} $out
          chmod 0555 $out
        '';
      in
      buMapper (
        buName: buConf:
        let
          # determines keypath
          buKeyPath = mkKeyPath buConf.keyPathOverride;
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
              ExecStartPre =
                let
                  preRun = buConf.preRunScript;
                in
                optionalString (preRun != { }) ''
                  ${bash} ${preRun.file} ${preRun.arguments}
                '';
              # ExecStart runs after all ExecStartPre commands have finished successfully
              ExecStart =
                let
                  job-args = join " " [
                    "-n ${buName}"
                    "-d ${(join " " buConf.sourceDirs)}"
                    "-t ${(join " " buConf.targetDirs)}"
                    "-r ${toString buConf.rolloverIntervalDays}"
                    "-k ${buKeyPath}"
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                    (optionalString (buConf.noEncrypt) "-x")
                  ];
                in
                ''
                  ${backup-job} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost =
                let
                  postRun = buConf.postRunScript;
                in
                optionalString (postRun != { }) ''
                  ${bash} ${postRun.file} ${postRun.arguments}
                '';
            };
          };
          # backup service timer
          timers."burenix-${buName}-backup" = {
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
              mkDir = "${pkgs.coreutils}/bin/mkdir";
            in
            {
              enable = true;
              description = "Target creator for Buenix backup [${buName}]";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              path = with pkgs; [ coreutils ];
              serviceConfig = {
                User = buConf.user;
                Group = buConf.group;
                Type = "oneshot";
                ExecStart = ''
                  ${mkDir} -p ${(join " " buConf.targetDirs)}
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
              ExecStartPre =
                let
                  preRun = buConf.preRunScript;
                in
                optionalString (preRun != { }) ''
                  ${bash} ${preRun.file} ${preRun.arguments}
                '';
              # ExecStart runs after all ExecStartPre commands have finished successfully
              ExecStart =
                let
                  job-args = join " " [
                    "-n ${buName}"
                    "-t ${(join " " buConf.targetDirs)}"
                    "-k ${buKeyPath}"
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                    (optionalString (buConf.noEncrypt) "-x")
                  ];
                in
                ''
                  ${restore-job} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost =
                let
                  postRun = buConf.postRunScript;
                in
                optionalString (postRun != { }) ''
                  ${bash} ${postRun.file} ${postRun.arguments}
                '';
            };
          };
          #
          #
        }
      );
    #
    #
  };
}
