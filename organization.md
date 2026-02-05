# Data organization in `grg/`

*What is `grg/` for?* It is for raw data, processed data, project-related metadata, and the code required to generate processed data from raw data.

*What is `grg/` not for?* It is not for personal analysis projects. 

## Top level structure

The top level directory in our "[hot](https://www.geeksforgeeks.org/system-design/differences-between-hot-data-and-cold-data-system-design/)" storage drive is `grg/`.

Beyond the top level there are two main types of subdirectory:
* Projects - these amalgamate data and processing for non-glider work, with glider data soft-linked in
* Glider data - for real time and delayed time data and processing

We break things down this way because gliders require special treatment. The data processing pipeline for gliders is being unified across gliders and projects.

This is what the top level looks like:
```
.
├── projects        # All project directories
├── seaglider-proc  # All processed seaglider glider data
├── seaglider-raw   # All raw seaglider data
├── slocum-proc     # All processed slocum data
└── slocum-raw      # All raw slocum data
```

## Glider data organization

We distinguish between two main types of glider data; raw and processed. Raw data are binary files produced by the glider, as well as all the configuration files. Essentially, raw data covers everything stored directly on the glider or transferred by the glider by satellite. Processed data covers everything derived from the raw data. 

We also distinguish between real-time and post-recovery data. Real-time includes anything transferred to shore or boat while the glider is in the water, either via iridium or radio comms. For most deployments real-time will contain a copy of the Slocum Fleet Mission Control (SFMC) directory. Post-recovery includes data transfered over cable or reading the storage card directly. There will neessarily be some overlap between the contents of these directories, since all the decimated files sent over iridium are also stored on the glider, this is not a problem because they don't take up much space.

Each glider deployment gets it's own subdirectory in raw. It is very important to name the deployments by data and serial number following the convention.

Naming convetion: YYYYMMDD_<NAME & SERIAL> (**YYYYMMDD is the deployment date**)

The raw directory should look like this:

```
slocum-raw
├── 20250204_sl685     # A glider deployment
│   ├── post-recovery   # Data downloaded after recovery
│   │   ├── flight      # Organized as on the glider. Contains .[dms][bc]d, .m[cl]g, autoexec.mi, sbdlist.dat, missions, mafiles
│   │   ├── cache       # .c[ac]c
│   │   ├── microrider  # .p, .q, .log, .cfg
│   │   ├── ad2cp       # .ad2cp, .cfg, .log
│   │   ├── azfp        #
│   │   └── science     # Organized as on the glider. Contains .[ent][bc]d, .n[cl], .mr[id], proglets.dat, tbdlist.dat, urider.ini, urider.dat
│   └── real-time       # A copy of SFMC directory
└── 20250919_sl1267    # Another glider deployment
```

Note that the flight and science data should be a perfect copy of whatever is on the glider, which usually looks something like:
```
flight/
├── bin
├── config
├── LOGS
├── mafiles
├── missions
├── SENTLOGS
└── STATE
```

At the deployment level the processed data should mirror the raw data using the same YYYYMMDD_<NAME & SERIAL> folder convention. Beyond this level data are organized as follows: 
```
glider-proc
├── 20250204_sl685
│   ├── software              # Software used to process the deployment
│   │   └── processing.sh     # Script used to process the data
│   ├── logs                  # Log files produced by processing software
│   │   └── glide.log         # A log file
│   ├── post-recovery
│   │   ├── sl685.dbd.nc     # Output of dbd2netcdf
│   │   ├── sl685.ebd.nc
│   │   └── sl685.pr.l2.nc   # Output of glide
│   └── real-time
│   │   ├── sl685.sbd.nc     # Output of dbd2netcdf
│   │   ├── sl685.tbd.nc
│   │   └── sl685.rt.l2.nc   # Output of glide      
└── 20250919_sl1267
```

## Project data organization

Project data are organized as appropriate for the project. For many projects, it is appropriate to break down the project into cruises or field operations. 

This is what a project directory might look like:

```
ARCTERX/
├── 2022-pilot  # A cruise
├── 2023-IOP    # Another cruise
├── 2025-IOP    # Another cruise
└── glider      # Processed glider data soft linked from slocum-proc
```

Within a cruise, standards may vary. Usually, some kind of shared drive is set up on the ship. A useful format to use is:

```
2025-IOP/
├── analysis       # Analysis conducted while at sea, should not be developed further here, but in personal folders
├── raw            # Raw data and metadata by instrument
│   ├── vmp        # .p
│   ├── mooring    # by mooring, and instrument
│   └── bowchain   # by deployment and sensor
├── figures        # Interesting analysis results created at sea, should not be developed further here
├── proc           # Processed data by instrument
│   ├── vmp
│   ├── mooring 
│   └── bowchain 
├── software       # All the .m, .ipynb, .py, .R code needed to created the processed data. 
│   ├── vmp
│   ├── mooring
│   └── bowchain
└── scripts        # Any automatic data shuttling scripts
```

It is logical to keep refining the processing code and processed data after the cruise. Prsonal analysis projects should be copied to new locations (e.g. the users home directory). 

