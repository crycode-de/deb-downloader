# deb-downloader

The deb-downloader is bash script to download deb files from a repository.

This can be used for example if you want to download a package to install it on an offline system.


## Usage

### Required arguments
* `-m <mirror url>`   The URL of the mirror.
* `-d <dist>`         Codename of the distribution.
* `-p <package>`      Name of the package which should be downloaded.

### Optional arguments
* `-c <components>`   Component(s) inside the repository. Defaults to 'main'.
* `-a <architecture>` Type of the processor architecture of the target system. Defaults to 'amd64'.
* `-D`                Detect and load all dependencies for the package.
* `-t`                Test run. Will only load the index files, detect the dependencies and print the download links.
* `-h`                Show this help.


## Examples

Download 'nano' for Ubuntu xenial (16.04)
```
./deb-downloader.sh -m http://archive.ubuntu.com/ubuntu/ -d xenial -a amd64 -p nano
```

Download 'gimp' for Ubuntu artful (17.10) using the 'universe' component
```
./deb-downloader.sh -m http://archive.ubuntu.com/ubuntu/ -d artful -c universe -a amd64 -p gimp
```

Download 'ntp' for Raspbian Stretch using the default Raspbian repo settings and including all dependencies
```
./deb-downloader.sh -m http://archive.raspbian.org/raspbian/ -d stretch -c "main contrib non-free rpi" -a armhf -p ntp -D
```


## License

Licensed under GPL Version 2

Copyright (c) 2018 Peter Müller <peter@crycode.de> (https://crycode.de/)
