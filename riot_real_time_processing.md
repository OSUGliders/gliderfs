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

Next I created a script to run over the L1 data, it lives in software and is called `sl685-pull-proc-push.sh`

```bash
#!/bin/bash

# Configuration
GLIDER="sl685"
DEPLOYMENT_DATE="20260317"

DEPLOYMENT_DIR="${DEPLOYMENT_DATE}_${GLIDER}"

REMOTE_SRC="glideruser@gliderfs2:/data/Dockserver/gliderfmc0/osu685/"
GRG="/home/server/pi/homes/cusackje/grg/"

LOCAL_RAW="${GRG}slocum-raw/${DEPLOYMENT_DIR}/real-time/from-glider/"
CACHE="${GRG}slocum-raw/${DEPLOYMENT_DIR}/cache/"
OUTPUT_L1="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l1/"

echo "Starting glider sync at $(date)"

rsync -aq "$REMOTE_SRC" "$LOCAL_RAW"

# Check if rsync was successful (Exit code 0)
if [ $? -eq 0 ]; then
    echo "Rsync complete. Checking for unprocessed files..."
    
    # Loop through all glider files in the local directory
    shopt -s nullglob

    for file in "$LOCAL_RAW"/*.[st]bd; do
        
        filename=$(basename -- "$file")
        
        # Result: /path/to/.../l1/flight123.sbd.nc
        expected_nc="${OUTPUT_L1}${filename}.nc"

        # Only process if the NetCDF file DOES NOT exist
        if [ ! -f "$expected_nc" ]; then
            echo "Processing new file: $filename"
            
            # Fixed missing $ on OUTPUT_L1 and file, and quoted variables to protect spaces
            /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$expected_nc" "$file" 
        fi
    done
else
    echo "Error: Rsync failed to connect or transfer files."
    exit 1
fi

echo "Job complete at $(date)"
```


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

Next I set up a timer

```
sudo vi /etc/systemd/system/sl685.timer
```

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

Start the timer

```
sudo systemctl daemon-reload
sudo systemctl enable sl685.timer
sudo systemctl start sl685.timer
```
