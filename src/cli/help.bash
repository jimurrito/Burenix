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
 USAGE:  burenix-cli <command> [data-source]

 COMMANDS:

   backup  <data-source>   Trigger a manual backup job for
                           the specified data source.

   restore <data-source>   Trigger a manual restore job for
                           the specified data source.

   ls      [data-source]   List data sources and their
                           available backup snapshots.
                           Optionally filter to one source.

   show    [data-source]   Print the raw JSON config for
                           one or all data sources.

   help                    Show this help menu.

--------------------------------------------------------
 EXAMPLES:

   burenix-cli backup my-data      # back up 'my-data'
   burenix-cli restore my-data     # restore 'my-data'
   burenix-cli ls                  # list all sources + snapshots
   burenix-cli ls my-data          # list snapshots for 'my-data'
   burenix-cli show                # print all data source configs
   burenix-cli show my-data        # print config for 'my-data'

EOF
