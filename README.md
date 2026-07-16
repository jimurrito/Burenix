# Burenix

![Nix](https://img.shields.io/badge/language-Nix%20%2F%20Bash-5277C3?logo=nixos)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

Backup and restore system for NixOS. Wraps GPG-encrypted tar archives into systemd timers, managed entirely through NixOS module options.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Full Example](#full-example)
- [Nix Flake](#nix-flake)
- [Module Options](#module-options)
- [CLI](#cli)
- [How It Works](#how-it-works)
- [License](#license)

---

## Requirements

- NixOS with Nix flakes enabled
- All other dependencies (`jq`, `gnutar`, `gpg`, `pigz`, `openssh`) are pulled in automatically by the module

---

## Installation

Add burenix to your flake inputs:

```nix
# flake.nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  burenix.url  = "github:jimurrito/burenix";
};
```

Import the module and configure a data source:

```nix
# configuration.nix (or equivalent)
{ inputs, ... }: {
  imports = [ inputs.burenix.nixosModules.default ];

  services.burenix = {
    enable = true;

    backups.<name> = {
      enable     = true;
      sourceDirs = [ "/path/to/source" ];
      targetDirs = [ "/path/to/target" ];
      backupTime = "Tue, 04:00:00";
    };
  };
}
```

Run `nixos-rebuild switch` and burenix will create a systemd service and timer for each defined data source.

---

## Usage

### Encryption key

Backups are encrypted with GPG symmetric encryption when `encryption.enable = true`. The key file should contain a plain-text passphrase:

```bash
echo "your-passphrase" > /path/to/keyfile
chmod 400 /path/to/keyfile
```

Set `encryption.keyPath` per data source to point to the passphrase file.

### Manual jobs via CLI

```bash
burenix-cli backup <data-source>    # trigger a manual backup
burenix-cli restore <data-source>   # trigger a manual restore
burenix-cli ls                      # list all sources and snapshots
burenix-cli ls <data-source>        # list snapshots for one source
burenix-cli show                    # print all data source configs
burenix-cli show <data-source>      # print config for one source
```

---

## Full Example

```nix
services.burenix = {
  enable = true;

  backups.postgres = {
    enable     = true;
    user       = "postgres";
    group      = "postgres";
    sourceDirs = [ "/var/lib/postgresql" ];
    targetDirs = [ "/mnt/nas/backups/postgres" ];
    tempDir    = "/tmp";
    backupTime = "daily, 02:00:00";
    usePigz    = true;

    encryption = {
      enable  = true;
      keyPath = "/path/to/keyfile";
    };

    rollover = {
      enable      = true;
      intervalDays = 30;
    };

    preRunScript = {
      enable    = true;
      file      = ./scripts/pg-dump.bash; # Just an example
      arguments = "--clean";
    };
  };

  backups.home = {
    enable     = true;
    sourceDirs = [ "/home/user" ];
    targetDirs = [ "/mnt/nas/backups/home" "/mnt/usb/backups/home" ];
    backupTime = "Sun, 03:00:00";
    checksum   = true;
  };
};
```

---

## Nix Flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    burenix.url = "github:jimurrito/burenix";
  };

  outputs = { nixpkgs, burenix, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        burenix.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

---

## Module Options

### Top-level (`services.burenix`)

| Option   | Type | Default | Description               |
| -------- | ---- | ------- | ------------------------- |
| `enable` | bool | `false` | Enable the burenix module |

### Per data source (`services.burenix.backups.<name>`)

| Option                    | Type           | Default     | Description                                              |
| ------------------------- | -------------- | ----------- | -------------------------------------------------------- |
| `enable`                  | bool           | `false`     | Enable this data source                                  |
| `user`                    | string         | `"root"`    | User the service runs as                                 |
| `group`                   | string         | `"burenix"` | Group the service runs as                                |
| `sourceDirs`              | list of string | `[]`        | Paths to back up                                         |
| `targetDirs`              | list of string | `[]`        | Destination paths to write backups to                    |
| `tempDir`                 | string         | `"/tmp"`    | Staging directory used during compression                |
| `backupTime`              | string or null | `null`      | Systemd `OnCalendar` schedule; `null` disables the timer |
| `useSSH`                  | bool           | `false`     | Use `scp` instead of `cp` for transfers                  |
| `usePigz`                 | bool           | `false`     | Use pigz (multi-threaded gzip) for compression           |
| `checksum`                | bool           | `false`     | Generate a SHA-256 checksum file alongside the archive   |
| `encryption.enable`       | bool           | `false`     | Enable GPG encryption                                    |
| `encryption.keyPath`      | string or null | `null`      | Path to the GPG passphrase file for this source          |
| `rollover.enable`         | bool           | `false`     | Enable automatic pruning of old archives                 |
| `rollover.intervalDays`   | number         | `14`        | Delete archives older than this many days                |
| `preRunScript.enable`     | bool           | `false`     | Run a script before the job starts                       |
| `preRunScript.file`       | path or null   | `null`      | Path to the pre-run script                               |
| `preRunScript.arguments`  | string         | `""`        | Arguments to pass to the pre-run script                  |
| `postRunScript.enable`    | bool           | `false`     | Run a script after the job completes                     |
| `postRunScript.file`      | path or null   | `null`      | Path to the post-run script                              |
| `postRunScript.arguments` | string         | `""`        | Arguments to pass to the post-run script                 |

---

## CLI

When `services.burenix.enable = true`, the `burenix-cli` command is available in the shell.

```
burenix-cli <command> [data-source]

  backup  <data-source>   Trigger a manual backup job for the data source.

  restore <data-source>   Trigger a manual restore job for the data source.

  ls      [data-source]   List data sources and available snapshots.
                          Optionally filter to a single source.

  show    [data-source]   Print the raw JSON config for one or all sources.

  logs    <data-source>   Show journalctl logs for a data source's backup
          <backup|restore> or restore service. Extra arguments are passed
          [journalctl-args] through to journalctl.

  help                    Show the help menu.
```

Examples:

```bash
burenix-cli logs my-data backup        # show backup logs
burenix-cli logs my-data restore -f    # follow restore logs live
burenix-cli logs my-data backup -n 50  # last 50 lines of backup logs
```

---

## How It Works

For each enabled data source, burenix creates:

- A systemd **service** (`burenix-<name>-backup.service`) that compresses source dirs into a tar archive, optionally encrypts it with GPG, and copies it to each target directory.
- A systemd **timer** (`burenix-<name>-backup.timer`) that triggers the service on the configured schedule (only created when `backupTime` is set).
- A systemd **service** (`burenix-<name>-restore.service`) that restores from the latest snapshot in the primary target directory.
- A systemd **service** (`burenix-<name>-init.service`) that creates target directories on boot.
- A JSON config file at `/etc/burenix/conf/<name>.json` consumed by the CLI and job scripts.

Backup filenames follow the pattern `burenix-<name>-<YYYY-MM-DDTHHMM>.tar.gz[.gpg]`. Archives older than `rollover.intervalDays` are automatically pruned from each target directory when `rollover.enable = true`.

---

## License

[GPL-3.0](LICENSE.md)
