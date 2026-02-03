# Slocum post-recovery workflow

We outline the workflow for processing Slocum glider data after the glider is recovered.

## Step 1: copy raw data from the glider into the deployment folder

Raw post-recovery data organization is specified in [organization.md](organization.md).

Usually, a deployment raw data folder will already exist because it is also the storage location for the raw real-time data. If not, create one from the template:

```bash
cd ~/grg/slocum-raw
cp -r YYYYMMDD_slXXX/ <YOUR DATE>_<YOUR SERIAL>
```

Copy the data into `~/grg/slocum-raw/YYYYMMDD_slXXX/post-recovery/<DATA SOURCE>/`. 

## Step 2: create a processed folder for the deployment

Usually, a deployment processed data folder will already exist because it is the storage location for the processed real-time data. If not, create one from the template:

```bash
cd ~/grg/slocum-proc
cp -r YYYYMMDD_slXXX/ <YOUR DATE>_<YOUR SERIAL>
```

## Step 3: create a shell script using dbd2netcdf to perform L0 -> L1 processing

Processing steps should be placed into shell scrips in `~/grg/slocum-proc/YYYYMMDD_slXXX/software/`.

Below is an example that could be named `post-recovery-dbd2netcdf.sh`.
```
# This script will run on gliderfs3

# Parameters
deployment=20260113_sl1267
glider=sl1267
save_dir=../post-recovery
cache=../../../slocum-raw/"${deployment}"/cache/
raw_root=../../../slocum-raw/"${deployment}"/post-recovery/

# Processing
dbd2netCDF -V 2>&1 | tee -a ../logs/dbd2netcdf.pr.log  # print version number to log
dbd2netCDF -v -o $save_dir/$glider.dbd.nc $raw_root/flight/*/*.d*d -C $cache 2>&1 | tee -a ../logs/dbd2netcdf.pr.log
dbd2netCDF -v -o $save_dir/$glider.ebd.nc $raw_root/science/*/*.e*d -C $cache 2>&1 | tee -a ../logs/dbd2netcdf.pr.log
```

The script should be modified as needed for each glider deployment. 

Once created, set the script permissions to execute, e.g.

```
chmod ug+x post-recovery-dbd2netcdf.sh
```

Run in the terminal using
```
./post-recovery-dbd2netcdf.sh
```

## Step 5: create a shell script using glide to perform L1 -> L2 -> L3 processing

Below is an example that could be named `post-recovery-glide.sh`.
```
# This script will run on gliderfs3

# Parameters
# deployment=20260113_sl1267
glider=sl1267
save_dir=../post-recovery

# Processing
glide -v 2>&1 | tee -a ../logs/glide.pr.log  # print version number to log
# glide --log-file=../logs/glide.pr.log --log-level=debug l2 $save_dir/$glider.sbd.nc $save_dir/$glider.tbd.nc -o $save_dir/$glider.pr.l2.nc -s 3
# glide --log-file=../logs/glide.pr.log --log-level=debug l3 $save_dir/$glider.pr.l2.nc -o $save_dir/$glider.pr.l2.nc -b 1
```

The script should be modified as needed for each glider deployment, including additional configuration for glide. It could be desirable to split L2 and L3 into separate scripts.
