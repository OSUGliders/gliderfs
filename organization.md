# Data organization

We try our best to keep everything organized in a logical structure with appropriate metadata.

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

We distinguish between two main types of glider data, raw, and processed. Raw mainly means the binary files produced by the glider. Processed covers everything else. 

Each glider deployment gets it's own subdirectory in raw. It is very important to name the deployments by data and serial number following the convention.

Naming convetion: YYYYMMDD_<NAME & SERIAL>

This is what the raw directory might look like:
```
glider-raw
├── 20250204_osu685     # A glider deployment
│   ├── post-recovery   # Data downloaded after recovery
│   │   ├── flight      # .sbd, .dbd, .mdl, .mbd, .mlg
│   │   ├── microrider  # .p, .q
│   │   └── science     # .tbd, .ebd, .nlg, .nbd
│   └── real-time       # Data transmitted over iridium (essentially a copy of SFMC directory)
└── 20250919_osu1267    # Another glider deployment
```

## Project data organization

Project data are organized as most appropriate for the project. For many projects, it is appropriate to break down the project into specific cruises. 

This is what a project directory might look like:
```
ARCTERX/
├── 2022-pilot  # A cruise
├── 2023-IOP    # Another cruise
├── 2025-IOP    # Another cruise
└── glider      # Processed glider data soft linked from glider-proc
```
