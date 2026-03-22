# Documentation for the RIOT real-time processing

First, I created folders in `slocum-raw` and `slocum-proc` using the templates. 

In the `slocum-raw` part, don't forget to add a directory for the cache files.

In `slocum-proc/20260317_sl685` I followed this structure:

```
├── logs
├── post-recovery
├── real-time
│   ├── acoustics  # for the RIOT csv
│   ├── erddap  # from glide running over dive segments at l2
│   ├── l1  # from dbd2ncdf
│   ├── l1-combined  # from dbd2ncdf
│   ├── l2  # glide l2
│   ├── l3  # glide l3, with epsilon data merged in.
│   ├── mri  # q2netcdf conversion of mri
│   └── mri-combined  # glide concat of the mri files
└── software
```

Create a bash script to process all the data `software/sl685-pull-proc-push.sh`. An example lives [here](./sl685-pull-proc-push.sh). The script started out relatively simple. However, it grew and grew over the course of the experiment as new features were added. We should definitely investigate using a better data pipeline tool, like snakemake, in the future. For the RIOT project only `acoustics`, `erddapp`, `l2`, and `l3` were pushed up to AWS.

Make the script executable.

```
chmod u+x sl685-pull-proc-push.sh
```

Setup systemd service. Need to execute with `/bin/bash` to avoid permission issues.

```
sudo vi /etc/systemd/system/sl685.service
```

Paste into the file:

```
[Unit]
Description=Pull and Process Real-Time Glider Files
After=network.target

[Service]
Type=oneshot
User=cusackje
Group=glider_group
ExecStart=/bin/bash /home/server/pi/homes/cusackje/grg/slocum-proc/20260317_sl685/software/sl685-pull-proc-push.sh

StandardOutput=journal
StandardError=journal
```

Setup service timer.

```
sudo vi /etc/systemd/system/sl685.timer
```

Paste into the file:

```
[Unit]
Description=Timer to periodically pull and process glider files

[Timer]
# Run every 3 minutes
OnCalendar=*:0/3
Persistent=true

[Install]
WantedBy=timers.target
```

Start timer.

```
sudo systemctl daemon-reload
sudo systemctl enable sl685.timer
sudo systemctl start sl685.timer
```

Monitor logs.

```
sudo journalctl -u sl685.service -e
```
