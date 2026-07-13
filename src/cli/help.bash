#!/usr/bin/env bash
#
cat << 'EOF'
  _                          _
 | |__  _   _ _ __ ___ _ __ (_)_  __
 | '_ \| | | | '__/ _ \ '_ \| \ \/ /
 | |_) | |_| | | |  __/ | | | |>  <
 |_.__/ \__,_|_|  \___|_| |_|_/_/\_\

 Backup and restore system for NixOS
--------------------------------------------------------
 USAGE:  burenix <command> [data-source]

 COMMANDS:

   backup  [data-source]   Trigger a manual backup job.
                           Omit [data-source] to use the
                           interactive wizard.

   restore                 Restore from a backup snapshot
                           via interactive wizard.

   ls                      List all data sources and their
                           available backup snapshots.

   help                    Show this help menu.

--------------------------------------------------------
 EXAMPLES:

   burenix backup              # wizard: pick a source
   burenix backup my-data      # back up 'my-data' directly
   burenix restore             # wizard: pick snap to restore
   burenix ls                  # list sources + snapshots

--------------------------------------------------------
 NOTES:

   - Backups are encrypted with GPG by default.
     Use noEncrypt = true in your NixOS config to disable.
   - Backup jobs run as systemd one-shot services.
     Track progress with:
       journalctl -u backup-<name>.service --follow
   - Config files live in /etc/burenix/conf/

EOF
