# Burenix

Backup and restore system for NixOS. Wraps GPG-encrypted tar archives into systemd timers, managed entirely through NixOS module options.

---

## Installation

Add burenix to your flake inputs and import the module:

```nix
# flake.nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  burenix.url  = "github:jimurrito/burenix";
};
```

Then in your NixOS configuration:

```nix
# configuration.nix (or equivalent)
{ inputs, ... }: {
  imports = [ inputs.burenix.nixosModules.default ];

  services.burenix = {
    enable   = true;
    keyPath  = "/root/backup-key";   # path to GPG passphrase file

    backups.my-data = {
      enable     = true;
      sourceDirs = [ "/home/user/documents" "/home/user/photos" ];
      targetDirs = [ "/mnt/backup-drive/my-data" ];
    };
  };
}
```

Run `nixos-rebuild switch` and burenix will create a systemd service and timer for each defined data source.

---

## Encryption key

Backups are encrypted with GPG symmetric encryption by default. The key file should contain a plain-text passphrase:

```bash
echo "your-passphrase" > /root/backup-key
chmod 400 /root/backup-key
```

To disable encryption for a data source, set `noEncrypt = true`.

---

## Module options

### Top-level (`services.burenix`)

| Option    | Type   | Default              | Description                     |
|-----------|--------|----------------------|---------------------------------|
| `enable`  | bool   | —                    | Enable the burenix module       |
| `keyPath` | string | `"/root/backup-key"` | Path to the GPG passphrase file |

### Per data source (`services.burenix.backups.<name>`)

| Option                   | Type           | Default          | Description                                    |
|--------------------------|----------------|------------------|------------------------------------------------|
| `enable`                 | bool           | —                | Enable this data source                        |
| `sourceDirs`             | list of string | `[]`             | Paths to back up                               |
| `targetDirs`             | list of string | `[]`             | Destination paths to write backups to          |
| `tempDir`                | string         | `"/tmp"`         | Staging directory used during compression      |
| `rolloverIntervalDays`   | number         | `14`             | Delete backups older than this many days       |
| `backupTime`             | string         | `"Tue, 4:00:00"` | Systemd `OnCalendar` schedule                  |
| `user`                   | string         | `"root"`         | User the backup service runs as                |
| `group`                  | string         | `"root"`         | Group the backup service runs as               |
| `useSSH`                 | bool           | `false`          | Use `scp` instead of `cp` for transfers        |
| `usePigz`                | bool           | `false`          | Use pigz (multi-threaded gzip) for compression |
| `noEncrypt`              | bool           | `false`          | Disable GPG encryption                         |
| `preRunScript.enable`    | bool           | —                | Run a script before the backup job             |
| `preRunScript.source`    | path           | —                | Path to the pre-run script                     |
| `preRunScript.arguments` | string         | `""`             | Arguments to pass to the pre-run script        |
| `postRunScript.enable`   | bool           | —                | Run a script after the backup job              |
| `postRunScript.source`   | path           | —                | Path to the post-run script                    |
| `postRunScript.arguments`| string         | `""`             | Arguments to pass to the post-run script       |

---

## Full example

```nix
services.burenix = {
  enable  = true;
  keyPath = "/root/backup-key";

  backups.postgres = {
    enable               = true;
    user                 = "postgres";
    group                = "postgres";
    sourceDirs           = [ "/var/lib/postgresql" ];
    targetDirs           = [ "/mnt/nas/backups/postgres" ];
    tempDir              = "/tmp";
    rolloverIntervalDays = 30;
    backupTime           = "daily, 2:00:00";
    usePigz              = true;

    preRunScript = {
      enable    = true;
      source    = ./scripts/pg-dump.bash;
      arguments = "--clean";
    };
  };

  backups.home = {
    enable     = true;
    sourceDirs = [ "/home/user" ];
    targetDirs = [ "/mnt/nas/backups/home" "/mnt/usb/backups/home" ];
    backupTime = "Sun, 3:00:00";
  };
};
```

---

## CLI

When `services.burenix.enable = true`, the `burenix` CLI is added to `environment.systemPackages`.

```
burenix <command> [data-source]

  backup  [data-source]   Trigger a manual backup job.
                          Omit [data-source] for interactive wizard.
  restore                 Restore from a snapshot via interactive wizard.
  ls                      List data sources and available snapshots.
  help                    Show the help menu.
```

Track a running backup job with:

```bash
journalctl -u backup-<name>.service --follow
```

---

## How it works

For each enabled data source, burenix creates:

- A systemd **service** (`backup-<name>.service`) that compresses source dirs into a tar archive, encrypts it with GPG, and copies it to each target directory.
- A systemd **timer** (`backup-<name>.timer`) that triggers the service on the configured schedule.
- Config files in `/etc/burenix/conf/` consumed by the CLI and backup job.

Backup filenames follow the pattern `backup-<name>-<timestamp>.tar.gz[.gpg]`. Archives older than `rolloverIntervalDays` are automatically pruned from each target directory.
