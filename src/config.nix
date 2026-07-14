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
      # Ensures jq is available
      systemPackages = [ pkgs.jq ];
      #
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
                name = buName;
                keyPath = optionalString (!buConf.noEncrypt) buKeyPath;
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
      in
      buMapper (
        buName: buConf:
        let
          # determines keypath
          buKeyPath = mkKeyPath buConf.keyPathOverride;
          # pre/post script
          mkScript =
            scriptConf:
            (mkIf (scriptConf != { }) ''
              ${bash} ${scriptConf.file} ${scriptConf.arguments}
            '');
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
                    "-r ${toString buConf.rolloverIntervalDays}"
                    (if (buConf.noEncrypt) then "-x" else "-k ${buKeyPath}")
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                  ];
                in
                ''
                  ${bash} ${./jobs/backup.bash} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost = mkScript buConf.postRunScript;
            };
          };
          # backup service timer
          timers."burenix-${buName}-backup" = mkIf (buConf.backupTime != "") {
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
              ExecStartPre = mkScript buConf.preRunScript;
              # ExecStart runs after all ExecStartPre commands have finished successfully
              ExecStart =
                let
                  job-args = join " " [
                    "-n ${buName}"
                    # grabs the first target as it is primary for automatic restores
                    "-t ${elemAt buConf.targetDirs 0}"
                    (if (buConf.noEncrypt) then "-x" else "-k ${buKeyPath}")
                    "-o ${buConf.tempDir}"
                    (optionalString (buConf.usePigz) "-p")
                    (optionalString (buConf.useSSH) "-s")
                  ];
                in
                ''
                  ${bash} ${./jobs/restore.bash} ${job-args}
                '';
              # Ran after all 'ExecStart' commands have finished successfully.
              ExecStartPost = mkScript buConf.postRunScript;
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
