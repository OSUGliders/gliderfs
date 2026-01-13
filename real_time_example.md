## Working with real-time data

In early January 2026 we tested a brand new Slocum G3S glider in Puget Sound. This document details the steps taken to monitor and process the real-time data.

I logged into gliderfs3 and created a skeleton raw data directory using the template.

```bash
cd grg/slocum-raw
cp -r YYYYMMDD_slXXX/ 20260113_sl1267
```

I setup a cron job to pull files from our SFMC server every minute. 

```
crontab -e  # then input the line below, save, and exit.
* * * * * rsync -va glideruser@gliderfs2:/data/Dockserver/gliderfmc0/unit_1267/ ~/grg/slocum-raw/20260113_sl1267/real-time/
```
