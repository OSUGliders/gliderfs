#!/bin/bash

# Configuration
GLIDER="sl685"
DEPLOYMENT_DATE="20260317"
REMOTE_SRC="glideruser@gliderfs2:/data/Dockserver/gliderfmc0/osu685/"
GRG="/home/server/pi/homes/cusackje/grg/"

# Files to exclude
EXCLUDE_FILES=(
    02830000.tbd
)

declare -A EXCLUDED_MAP
for excl in "${EXCLUDE_FILES[@]}"; do
    EXCLUDED_MAP["$excl"]=1
done

DEPLOYMENT_DIR="${DEPLOYMENT_DATE}_${GLIDER}"

LOCAL_RAW="${GRG}slocum-raw/${DEPLOYMENT_DIR}/real-time/"
CACHE="${GRG}slocum-raw/${DEPLOYMENT_DIR}/cache/"
OUTPUT_L1="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l1/"
OUTPUT_L1_COMBINED="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l1-combined/"
OUTPUT_MRI="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/mri/"
OUTPUT_MRI_COMBINED="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/mri-combined/"
OUTPUT_L2="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l2/"
OUTPUT_L3="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/l3/"
OUTPUT_ERDDAP="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/erddap/"
OUTPUT_ACOUSTICS="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/acoustics/"
LOG_DIR="${GRG}slocum-proc/${DEPLOYMENT_DIR}/logs/"
SOFTWARE="${GRG}slocum-proc/${DEPLOYMENT_DIR}/software/"

RIOT_CSV="${OUTPUT_ACOUSTICS}${GLIDER}_riot_data.csv"
ERDDAP_LOG="${LOG_DIR}${GLIDER}_erddap.log"
PROCESSED_LOG="${LOG_DIR}${GLIDER}_l2_processed.txt"
LOG_L2="${LOG_DIR}${GLIDER}_l2.log"
LOG_L3="${LOG_DIR}${GLIDER}_l3.log"

COMBINED_SBD="${OUTPUT_L1_COMBINED}${DEPLOYMENT_DIR}.sbd.nc"
COMBINED_TBD="${OUTPUT_L1_COMBINED}${DEPLOYMENT_DIR}.tbd.nc"
COMBINED_MRI="${OUTPUT_MRI_COMBINED}${DEPLOYMENT_DIR}.mri.nc"
COMBINED_L2="${OUTPUT_L2}${DEPLOYMENT_DIR}.l2.nc"
COMBINED_L3="${OUTPUT_L3}${DEPLOYMENT_DIR}.l3.nc"

# Shrink file by fixing unlimited dimensions and chunk size
shrink_nc() {
    local nc_file="$1"
    [[ ! -f "$nc_file" ]] && return

    local i_len=$(ncdump -h "$nc_file" | grep -m1 "i = UNLIMITED" | grep -Eo '[0-9]+')
    local j_len=$(ncdump -h "$nc_file" | grep -m1 "j = UNLIMITED" | grep -Eo '[0-9]+')
    i_len=${i_len:-1}
    j_len=${j_len:-1}

    nccopy -u -c "i/${i_len},j/${j_len}" "$nc_file" "${nc_file}.tmp" && mv "${nc_file}.tmp" "$nc_file"
}

touch "$PROCESSED_LOG"

echo "Starting glider sync at $(date)"
rsync -vrt "$REMOTE_SRC" "$LOCAL_RAW"
RSYNC_EXIT=$?
if [[ $RSYNC_EXIT -ne 0 && $RSYNC_EXIT -ne 23 && $RSYNC_EXIT -ne 24 ]]; then
    echo "Error: Rsync failed to connect or transfer files (exit code $RSYNC_EXIT)." >&2
    exit 1
elif [[ $RSYNC_EXIT -eq 23 || $RSYNC_EXIT -eq 24 ]]; then
    echo "Warning: Rsync completed with partial transfer. Continuing."
fi

echo "Checking for unprocessed files..."

shopt -s nullglob
NEW_L1_FOUND=false
NEW_MRI_FOUND=false
SBD_FILES=()
TBD_FILES=()

# Process flight/science files
for file in "$LOCAL_RAW"/from-glider/*.[st]bd; do
    filename=$(basename -- "$file")
    [[ -n "${EXCLUDED_MAP[$filename]:-}" ]] && continue
    [[ ! -s "$file" ]] && continue

    if [[ "$filename" == *.sbd ]]; then SBD_FILES+=("$file"); else TBD_FILES+=("$file"); fi

    expected_nc="${OUTPUT_L1}${filename}.nc"
    if [[ ! -f "$expected_nc" ]]; then
        echo "Processing L1: $filename"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$expected_nc" "$file"
        shrink_nc "$expected_nc"
        NEW_L1_FOUND=true
    fi
done

# Process MRI files
for file in "$LOCAL_RAW"/from-glider/*.mri; do
    filename=$(basename -- "$file")
    [[ -n "${EXCLUDED_MAP[$filename]:-}" ]] && continue
    [[ ! -s "$file" ]] && continue

    expected_nc="${OUTPUT_MRI}${filename}.nc"
    if [[ ! -f "$expected_nc" ]]; then
        echo "Processing MRI: $filename"
        mkdir -p "$OUTPUT_MRI"
        q2netcdf --nc "$expected_nc" "$file"
        NEW_MRI_FOUND=true
    fi
done

# Determine what needs combining/rebuilding
NEED_L1_COMBINED=false
$NEW_L1_FOUND || [[ ! -f "$COMBINED_SBD" ]] || [[ ! -f "$COMBINED_TBD" ]] && NEED_L1_COMBINED=true

NEED_MRI_COMBINED=false
if $NEW_MRI_FOUND || [[ ! -f "$COMBINED_MRI" ]]; then
    ls "$OUTPUT_MRI"/*.nc 1> /dev/null 2>&1 && NEED_MRI_COMBINED=true
fi

# Combine L1 files
if $NEED_L1_COMBINED; then
    mkdir -p "$OUTPUT_L1_COMBINED"
    if [[ ${#SBD_FILES[@]} -gt 0 ]]; then
        echo "Combining sbd files"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$COMBINED_SBD" "${SBD_FILES[@]}"
        shrink_nc "$COMBINED_SBD"
    fi
    if [[ ${#TBD_FILES[@]} -gt 0 ]]; then
        echo "Combining tbd files"
        /usr/local/bin/dbd2netCDF -v -C "$CACHE" -o "$COMBINED_TBD" "${TBD_FILES[@]}"
        shrink_nc "$COMBINED_TBD"
    fi
fi

# Concatenate MRI files
if $NEED_MRI_COMBINED; then
    echo "Concatenating MRI files"
    mkdir -p "$OUTPUT_MRI_COMBINED"
    glide concat -o "$COMBINED_MRI" "$OUTPUT_MRI"/*.nc
fi

# Run L2/L3 generation and MRI merging
if $NEED_L1_COMBINED || $NEED_MRI_COMBINED || [[ ! -f "$COMBINED_L3" ]]; then
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
                -b 6 -d 800 \
                -c "${SOFTWARE}${GLIDER}.glide.config.yml" \
                "$COMBINED_L2"

            # Merge MRI into L3 safely using a temp file
            if [[ -f "$COMBINED_L3" ]] && [[ -f "$COMBINED_MRI" ]]; then
                echo "Merging MRI data into L3"
                glide merge -o "${COMBINED_L3}.tmp" -w "$COMBINED_L3" "$COMBINED_MRI" q && \
                mv "${COMBINED_L3}.tmp" "$COMBINED_L3"
            fi
        fi
    fi
fi

echo "Checking for ERDDAP L2 segment processing..."

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
        echo "Generating ERDDAP L2 for: $segment"
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

# Sync processed data to AWS (excluding intermediate/raw NetCDFs)
REAL_TIME="${GRG}slocum-proc/${DEPLOYMENT_DIR}/real-time/"
AWS_DEST="riot:data/${DEPLOYMENT_DIR}/"

echo "Syncing to AWS at $(date)"
rsync -rlvzt --exclude 'l1/' --exclude 'l1-combined/' --exclude 'mri/' --exclude 'mri-combined/' "$REAL_TIME" "$AWS_DEST"

echo "Job complete at $(date)"
