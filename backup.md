# Backups

We back up `grg/` from tier 2 (`/home/server/hpc/grg`) to tier 3 (`/storage/t3/dept/ceoas/grg/backup`) with [restic](https://restic.net/) (installed in [configuration.md](configuration.md)). Backups run as the `gliderhelper` service account on a systemd timer. 

Setup files live in [backup/](backup/) and are installed from there.

```
sudo ./install.sh          # copy scripts, units and env files into place
sudo ./validate-install.sh # check the install, repos, timers and snapshot age
```

`daemon-reload` takes 90 s on this machine (a systemd problem, not ours), so `install.sh` only reloads when a unit file actually changed.

Recipients for failure emails are not in git. Copy `notify.env.example` to `notify.env` and edit it before installing.

## Schedule

| When | What |
| --- | --- |
| Daily 02:00 (+ up to 30 min) | `backup` then `forget` |
| Sunday 04:00 (+ up to 1 h) | `prune`, then integrity check of a rotating 1/4 of the repo |

Raw data keeps 30 daily, 52 weekly and all monthly snapshots. Email goes out only on failure, and a flag file appears in `backup/STATUS/`. The flag clears on the next good run.

## Restoring

```sh
export RESTIC_REPOSITORY=/storage/t3/dept/ceoas/grg/backup/slocum-raw
restic --insecure-no-password snapshots
restic --insecure-no-password restore latest --target /tmp/restore \
    --include /home/server/hpc/grg/slocum-raw/20260514_sl1267
```

Restore somewhere empty and copy back by hand. Worth testing once in a while.

## Adding another tree

Create the repo as `gliderhelper`, then open it to the `glider_t3` group. restic makes new repos readable only by their owner, so without the `chmod` nobody else can restore from it or run `validate-install.sh`.

```sh
REPO=/storage/t3/dept/ceoas/grg/backup/<tree>
mkdir -p "$(dirname "$REPO")"
sudo -u gliderhelper restic --insecure-no-password --no-cache init --repo "$REPO"
sudo chmod -R g+rwX "$REPO"
```

Copy `slocum-raw.env` to `<tree>.env`, set `SOURCE_DIR` and `RESTIC_REPOSITORY`, then

```sh
sudo ./install.sh
sudo systemctl start --no-block restic-backup@<tree>.service   # first backup, don't wait for 02:00
sudo systemctl enable --now restic-backup@<tree>.timer restic-check@<tree>.timer
sudo ./validate-install.sh
```

Raw trees use `excludes-raw.txt`, which only skips OS junk and version control. Processed trees use `excludes.txt`, which also skips caches and environments. Don't point a raw tree at `excludes.txt`: it drops `*.tmp` and other files that are real instrument data.

## Checking on it

```sh
systemctl list-timers 'restic-*'
sudo journalctl -u restic-backup@slocum-raw -n 50
```
