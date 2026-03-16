# Documentation for the RIOT real-time processing

First, I created folders in `slocum-raw` and `slocum-proc` using the templates. The `slocum-proc` following structure was created in `20260317_sl685`:

```
├── logs
├── post-recovery
├── real-time
│   ├── acoustics  # for the RIOT csv
│   ├── erddap  # from glide running over dive segments at l2
│   ├── l1  # from dbd2ncdf
│   ├── l2  # glide l2
│   └── l3  # glide l3
└── software
```

Next I created a script to run over the L1 data


Next I setup a systemd service

```
sudo vi /etc/systemd/system/sl685.service
```

```
[Unit]
Description=Pull and Process Real-Time Glider Files
After=network.target

[Service]
Type=oneshot
User=cusackje
Group=glider_group
ExecStart=/home/server/pi/homes/cusackje/grg/slocum-proc/20260317_sl685/software/sl685-pull-proc-push.sh

StandardOutput=journal
StandardError=journal
```
