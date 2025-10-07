# Data organization

We try our best to keep everything organized in a logical structure with appropriate metadata.

What is `grg/` for? It is for raw data, processed data, project-related metadata, and the code required to generate processed data from raw data.

What is `grg/` not for? It is not for personal analysis projects. 

## Top level structure

The top level directory in our "[hot](https://www.geeksforgeeks.org/system-design/differences-between-hot-data-and-cold-data-system-design/)" storage drive is `grg/`.

Beyond the top level there are two main types of subdirectory:
* Projects - these amalgamate data and processing for non-glider work, with glider data soft-linked in
* Glider data - for real time and delayed time data and processing

We break things down this way because gliders require special treatment. The data processing pipeline for gliders is being unified across gliders and projects.

This is what the top level might look like:
```
.
├── ARCTERX        # A project
├── glider-proc    # All processed glider data
├── glider-raw     # All raw glider data, including real-time and post-recovery
├── RIOT           # Another project
├── SUNRISE        # Another project
└── TH_Line        # Another project
```

## Glider data organization

We distinguish between two main types of glider data; raw and processed. Raw data are binary files produced by the glider. Processed covers everything else. 

Each glider deployment gets it's own subdirectory in raw. It is very important to name the deployments by data and serial number following the convention.

Naming convetion: YYYYMMDD_<NAME & SERIAL>

This is what the raw directory might look like:
```
glider-raw
├── 20250204_osu685     # A glider deployment
│   ├── post-recovery   # Data downloaded after recovery
│   │   ├── flight      # .sbd, .dbd, .mdl, .mbd, .mlg
│   │   ├── cache       # .cac
│   │   ├── microrider  # .p, .q
│   │   └── science     # .tbd, .ebd, .nlg, .nbd
│   └── real-time       # Data transmitted over iridium (essentially a copy of SFMC directory)
└── 20250919_osu1267    # Another glider deployment
```

At the highest level the processed data should mirror the raw data:
glider-proc
├── 20250204_osu685
│   ├── processing.sh      # Script to run dbd2netcdf & glide on data
│   ├── post-recovery
│   │   ├── osu685.dbd.nc  # Output of dbd2netcdf
│   │   ├── osu685.ebd.nc
│   │   └── osu685.l2.nc   # Output of glide
│   └── real-time      
└── 20250919_osu1267
```

## Project data organization

Project data are organized as appropriate for the project. For many projects, it is appropriate to break down the project into cruises or field operations. 

This is what a project directory might look like:
```
ARCTERX/
├── 2022-pilot  # A cruise
├── 2023-IOP    # Another cruise
├── 2025-IOP    # Another cruise
└── glider      # Processed glider data soft linked from glider-proc
```

What about within a cruise? Usually, some kind of shared drive is set up on the ship. Standards of organization these drives vary, but a useful format to use is:

```
2025-IOP/
├── analysis       # Analysis conducted while at sea, should not be developed further here, but in personal folders
├── data           # Raw data and metadata by instrument
│   ├── vmp        # .p
│   ├── mooring    # by mooring, and instrument
│   └── bowchain   # by deployment and sensor
├── figures        # Interesting analysis results created at sea, should not be developed further here
├── proc           # Processed data by instrument
│   ├── vmp
│   ├── mooring 
│   └── bowchain 
├── proc-code
│   ├── vmp
│   ├── mooring
│   └── bowchain
└── scripts        # Any automatic data shuttling scripts
```

