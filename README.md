# gliderfs - the glider file server

Specific documentation for our group file server is kept here. 

We use this server for moving files around, automated data pipelies, and some minimal data processing.

How was it created? We asked Thomas Olson to spin us up an Ubuntu 24.04 LTS VM with 4 CPUs, 8 GB RAM and 256 GB of memory (all expandable in the future).

## Access

Log in via ssh while on the OSU network.

```
ssh [YOUR_ONID]@gliderfs3.ceoas.oregonstate.edu
```

Once logged in, our group storage is located at `/home/server/hpc/grg/`. For convenience, create a soft link of this directory to your home directory.

```
ln -s /home/server/hpc/grg ~/grg
```

## Organization

Good organization of data is critical and is described in separate document: [organization.md](organization.md).

## Configuration

Configuration instructions: [configuration.md](configuration.md)
