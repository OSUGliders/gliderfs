## Working with real-time data

In early January 2026 we tested a brand new Slocum G3S glider in Puget Sound. This document details the steps taken to monitor and process the real-time data, with some later additions as we learned from our mistakes.

Log into gliderfs3 and create a skeleton raw data directory using the template.

```bash
cd ~/grg/slocum-raw
cp -r YYYYMMDD_slXXX/ 20260113_sl1267
```

Create a skeleton processed data directory using the template.

```bash
cd ~/grg/slocum-proc
cp -r YYYYMMDD_slXXX/ 20260113_sl1267
```

Setup a cron job to pull files from our SFMC server every minute. 

```
crontab -e  # then input the line below, save, and exit.
* * * * * rsync -vrt glideruser@gliderfs2:/data/Dockserver/gliderfmc0/osu1267/ ~/grg/slocum-raw/20260113_sl1267/real-time/ > /dev/null 2>&1
```
I included the last part `> /dev/null 2>&1` to stop cron from emailing me. Note that we do not use the `-a` option because that messes up permissions in the target folder.

Note in order for the cron job to work you need a ssh-key access between gliderfs2 and gliderfs3. When the ssh key is in place, run rsync outside of the cron job once, as you have to confirm the usage of the ssh key on the first use. If you fail to do this the cron job will run into a host authentication error. I simply ran:

```
rsync -vrt glideruser@gliderfs2:/data/Dockserver/gliderfmc0/osu1267/ ~/grg/slocum-raw/20260113_sl1267/real-time/
```

Create a processing script `~/slocum-proc/20260113_sl1267/software/real-time-processing.sh`.

```
# This script will run on gliderfs3

# Parameters
deployment=YYYYMMDD_slXXX/
glider=slXXXX
save_dir=../real-time
cache=../../../slocum-raw/"${deployment}"/cache/

# Processing
raw_root=../../../slocum-raw/"${deployment}"/real-time/
dbd2netCDF -V 2>&1 | tee -a ../logs/dbd2netcdf.rt.log  # print version number to log
dbd2netCDF -v -o $save_dir/$glider.sbd.nc $raw_root/from-glider/*.sbd -C $cache 2>&1 | tee -a ../logs/dbd2netcdf.rt.log
dbd2netCDF -v -o $save_dir/$glider.tbd.nc $raw_root/from-glider/*.tbd -C $cache 2>&1 | tee -a ../logs/dbd2netcdf.rt.log
dbd2netCDF -v -o $save_dir/$glider.dbd.nc $raw_root/from-glider/*.dbd -C $cache 2>&1 | tee -a ../logs/dbd2netcdf.rt.log
glide -v 2>&1 | tee -a ../logs/glide.rt.log  # print version number to log
# glide --log-file=../logs/glide.rt.log --log-level=debug l2 $save_dir/$glider.sbd.nc $save_dir/$glider.tbd.nc -o $save_dir/$glider.l2.rt.nc -s 3
# glide --log-file=../logs/glide.rt.log --log-level=debug l3 $save_dir/$glider.l2.rt.nc -o $save_dir/$glider.l3.rt.nc -b 1
```

Run the script.

```
cd ~/slocum-proc/20260113_sl1267/software/
./real-time-processing.sh
```

After recovery, stop the cron job.

```
crontab -e
# Then comment out the line
```

In summary, real-time processing was not fully setup for this job.
