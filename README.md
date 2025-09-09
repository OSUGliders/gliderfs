# gliderfs - the glider file server

Specific documentation for our group file server is kept here. 

We use this server for moving files around, automated data pipelies, and some minimal data processing.

How was it created? We asked Thomas Olson to spin us up an Ubuntu 24.04 LTS VM with 4 CPUs, 8 GB RAM and 256 GB of memory (all expandable in the future).

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

Now lets try and install `glide`.

```
sudo apt install pipx
pipx ensurepath  # strictly only sures local path, doesn't help for global installs

```

I ran into problems here: https://github.com/pypa/pipx/issues/1481
