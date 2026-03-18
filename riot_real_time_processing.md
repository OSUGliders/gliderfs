# Documentation for the RIOT real-time processing

First, I created folders in `slocum-raw` and `slocum-proc` using the templates. In `slocum-proc/20260317_sl685` I followed this structure:

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

Script to process all the data `software/sl685-pull-proc-push.sh`.

```bash
#!/bin/bash

# Configuration
GLIDER="sl685"
DEPLOYMENT_DATE="20260317"

# Files to exclude from processing (basenames, e.g. "osu685_2026_074_3_1.sbd")
EXCLUDE_FILES=(
    02830000.tbd
)

# Convert exclusion list to an associative array for fast O(1) lookups
declare -A EXCLUDED_MAP
for excl in "${EXCLUDE_FILES[@]}"; do
    EXCLUDED_MAP["$excl"]=1
done

DEPLOYMENT_DIR="${DEPLOYMENT_DATE}_${GLIDER}"

REMOTE_SRC="glideruser@gliderfs2:/data/Dockserver/gliderfmc0/osu685/"
GRG="/home/server/pi/homes/cusackje/grg/"

LOCAL_RAW="${GRG}slocum-raw/${DEPLOYMENT_DIR}/real-time/"
CACHE="${GRG}slocum-raw/${DEPLOYMENT_DIR}/cache/"
OUTPUT_L1="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l1/"
OUTPUT_ERDDAP="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/erddap/"
OUTPUT_ACOUSTICS="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/acoustics/"
LOG_DIR="${GRG}slocum-proc/${DEPLOYMENT_DIR}/logs/"
SOFTWARE="${GRG}slocum-proc/${DEPLOYMENT_DIR}/software/"
RIOT_CSV="${OUTPUT_ACOUSTICS}${GLIDER}_riot_data.csv"
ERDDAP_LOG="${LOG_DIR}${GLIDER}_erddap.log"
PROCESSED_LOG="${LOG_DIR}${GLIDER}_l2_processed.txt"
OUTPUT_L1_COMBINED="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l1-combined/"
OUTPUT_L2="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l2/"
OUTPUT_L3="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l3/"
COMBINED_SBD="${OUTPUT_L1_COMBINED}${DEPLOYMENT_DIR}.sbd.nc"
COMBINED_TBD="${OUTPUT_L1_COMBINED}${DEPLOYMENT_DIR}.tbd.nc"
COMBINED_L2="${OUTPUT_L2}${DEPLOYMENT_DIR}.l2.nc"
COMBINED_L3="${OUTPUT_L3}${DEPLOYMENT_DIR}.l3.nc"
LOG_L2="${LOG_DIR}${GLIDER}_l2.log"
LOG_L3="${LOG_DIR}${GLIDER}_l3.log"

touch "$PROCESSED_LOG"

echo "Starting glider sync at $(date)"

rsync -vrt "$REMOTE_SRC" "$LOCAL_RAW"
RSYNC_EXIT=$?
if [[ $RSYNC_EXIT -ne 0 && $RSYNC_EXIT -ne 23 && $RSYNC_EXIT -ne 24 ]]; then
    echo "Error: Rsync failed to connect or transfer files (exit code $RSYNC_EXIT)." >&2
    exit 1
elif [[ $RSYNC_EXIT -eq 23 || $RSYNC_EXIT -eq 24 ]]; then
    echo "Warning: Rsync completed with partial transfer (exit code $RSYNC_EXIT). Continuing."
fi

echo "Rsync complete. Checking for unprocessed files"

shopt -s nullglob
NEW_FILES_FOUND=false
SBD_FILES=()
TBD_FILES=()

# Loop through files to process
for file in "$LOCAL_RAW"/from-glider/*.[st]bd; do
    filename=$(basename -- "$file")

    # Skip excluded files
    [[ -n "${EXCLUDED_MAP[$filename]:-}" ]] && echo "Skipping excluded file: $filename" && continue
    [[ ! -s "$file" ]] && echo "Skipping empty file: $filename" && continue
    
    # Store in respective arrays for the combined step later
    if [[ "$filename" == *.sbd ]]; then
        SBD_FILES+=("$file")
    else
        TBD_FILES+=("$file")
    fi

    expected_nc="${OUTPUT_L1}${filename}.nc"

    # Only process if the NetCDF file DOES NOT exist
    if [[ ! -f "$expected_nc" ]]; then
        echo "Processing new file: $filename"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$expected_nc" "$file"
        NEW_FILES_FOUND=true
    fi
done

# Regenerate combined sbd.nc and tbd.nc if new files were found or combined outputs don't exist yet
NEED_COMBINED=false
if $NEW_FILES_FOUND; then
    echo "New files detected — regenerating combined NetCDF files"
    NEED_COMBINED=true
elif [[ ! -f "$COMBINED_SBD" ]] || [[ ! -f "$COMBINED_TBD" ]]; then
    echo "Combined NetCDF files missing — generating from available data"
    NEED_COMBINED=true
fi

if $NEED_COMBINED; then
    if [[ ${#SBD_FILES[@]} -gt 0 ]]; then
        echo "Combining ${#SBD_FILES[@]} sbd files into sbd.nc"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$COMBINED_SBD" "${SBD_FILES[@]}"
    fi
    if [[ ${#TBD_FILES[@]} -gt 0 ]]; then
        echo "Combining ${#TBD_FILES[@]} tbd files into tbd.nc"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$COMBINED_TBD" "${TBD_FILES[@]}"
    fi

    # Run L2 and L3 on combined files
    if [[ -f "$COMBINED_SBD" ]] && [[ -f "$COMBINED_TBD" ]]; then
        echo "Generating combined L2"
        glide --log-level=debug --log-file="$LOG_L2" l2 \
            -c "${SOFTWARE}${GLIDER}.glide.config.yml" \
            -o "$COMBINED_L2" \
            "$COMBINED_SBD" "$COMBINED_TBD"

        if [[ -f "$COMBINED_L2" ]]; then
            echo "Generating combined L3"
            glide --log-level=debug --log-file="$LOG_L3" l3 \
                -o "$COMBINED_L3" \
                -b 5 -d 550 \
                -c "${SOFTWARE}${GLIDER}.glide.config.yml" \
                "$COMBINED_L2"
        fi
    fi
fi

echo "Checking for L2 processing..."

declare -A PROCESSED_MAP
while IFS= read -r line; do
    [[ -n "$line" ]] && PROCESSED_MAP["$line"]=1
done < "$PROCESSED_LOG"

for flt_nc in "$OUTPUT_L1"/*.sbd.nc; do
    [[ -f "$flt_nc" ]] || continue

    flt_basename=$(basename "$flt_nc")
    segment="${flt_basename%.sbd.nc}"
    sci_nc="${OUTPUT_L1}${segment}.tbd.nc"

    [[ -f "$sci_nc" ]] || continue

    if [[ -z "${PROCESSED_MAP[$segment]:-}" ]]; then
        echo "Generating L2 for: $segment"
        if glide --log-level=debug --log-file="$ERDDAP_LOG" l2 \
            -o "$OUTPUT_ERDDAP" \
            --config="${SOFTWARE}${GLIDER}.glide.config.yml" \
            -r "$RIOT_CSV" --riot-positions \
            -g "$GLIDER" \
            "$flt_nc" "$sci_nc"; then
            
            echo "$segment" >> "$PROCESSED_LOG"
            PROCESSED_MAP["$segment"]=1
        fi
    fi
done

# Sync processed data to AWS
REAL_TIME="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/"
AWS_DEST="riot:data/${DEPLOYMENT_DIR}/"

echo "Syncing to AWS at $(date)"
rsync -rlvzt --exclude 'l1/' --exclude 'l1-combined/' "$REAL_TIME" "$AWS_DEST"

echo "Job complete at $(date)"
```

Make script executable.

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
