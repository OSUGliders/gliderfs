## Initial setup

**Only one person needs to do this for the packages to be globally available. As of 9/10/25 this has already been done.**

First, install some packages that we need use [`dbd2netcdf`](https://github.com/OSUGliders/dbd2netcdf)

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

Next, install [`glide`](https://github.com/OSUGliders/glide) with `pipx`. In future versions of Ubuntu (26.04), this should be much easier. Unfortunately 24.04 only includes pipx version 1.4 which doesn't allow for global installations of packages. To get around this I dug up this comment in an GitHub issue: https://github.com/pypa/pipx/issues/1481#issuecomment-2593233084. Someone backported pipx 1.6 to Ubuntu 24.04 and it seems to work.

```
wget https://github.com/zinc75/pipx-1.6.0-backport-ubuntu-2404-lts/releases/download/1.6.0-1/pipx_1.6.0-1_all.deb
sudo dpkg -i pipx_1.6.0-1_all.deb
```

With `pipx` installed, run

```
sudo pipx install --global git+https://github.com/OSUGliders/glide.git
```

This appears to have worked. Now we have both dbd2netcdf and glide available for Slocum processing. If glide needs to be updated, it can be reinstalled using

```
sudo pipx install --force --global git+https://github.com/OSUGliders/glide.git
```

We also install the [nco tools](https://nco.sourceforge.net/) to operate on netCDF files.

```
sudo apt install nco
```

Installing pixi. I ran:

```
sudo curl -fsSL https://pixi.sh/install.sh | PIXI_BIN_DIR=/usr/local/bin PIXI_NO_PATH_UPDATE=1 bash
```

but then got a permission error and had to move the temporary file, e.g. sudo mv /tmp/tmp.[HASH]/pixi /usr/local/bin/pixi

Installing pyturb, our new and experimental microstructure processing software.

```
sudo pipx install --global git+https://github.com/oceancascades/pyturb.git
```

That worked without hiccups...!

## Updating dbd2netcdf

Log in and checkout the latest version of dbd2netdf from git. I (Jesse) last did this while writing this page on 2026-02-04.

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
sudo cmake --install build
```

I got the following output:
```
-- Install configuration: "Release"
-- Installing: /usr/local/bin/dbd2netCDF
-- Installing: /usr/local/bin/pd02netCDF
-- Installing: /usr/local/bin/dbd2csv
-- Installing: /usr/local/bin/dbdSensors
-- Installing: /usr/local/bin/decompressTWR
-- Installing: /usr/local/man/man1/dbd2netCDF.1
-- Installing: /usr/local/man/man1/dbd2csv.1
-- Installing: /usr/local/man/man1/dbdSensors.1
CMake Error at build/cmake_install.cmake:83 (file):
  file failed to open for writing (Permission denied):

    /home/server/pi/homes/cusackje/dbd2netcdf/build/install_manifest.txt
```

Most of the parts were successfully installed into `/usr/local/bin/`. I don't think the manifest error is important. 
