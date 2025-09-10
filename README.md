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

## Initial setup

Install some packages that we need to get [dbd2netcdf](https://github.com/OSUGliders/dbd2netcdf) running

```
cd ~
sudo apt install cmake libnetcdf-dev libhdf5-dev build-essential netcdf-bin
git clone https://github.com/OSUGliders/dbd2netcdf
cd dbd2netcdf
# follow the instructions in INSTALL, which were
cmake .
make
make check
sudo make install  # otherwise permission denied... 
```

This threw some errors for me on make check and the last part of make install, but does appear to have installed successfully. 

Now lets try and install `glide` with `pipx`. In future versions of of Ubuntu (26.04), this should be much easier. Unfortunately 24.04 only includes pipx version 1.4 which doesn't allow for global installations of packages. To get around this I dug up this comment in an GitHub issue: https://github.com/pypa/pipx/issues/1481#issuecomment-2593233084. Yes, someone backported pipx 1.6 to Ubuntu 24.04. It seems to work.

```
wget https://github.com/zinc75/pipx-1.6.0-backport-ubuntu-2404-lts/releases/download/1.6.0-1/pipx_1.6.0-1_all.deb
sudo dpkg -i pipx_1.6.0-1_all.deb
```

With `pipx` installed, run

```
sudo pipx install --global git+https://github.com/OSUGliders/glide.git
```

This appears to have worked. Now we have both dbd2netcdf and glide available for Slocum processing. 



