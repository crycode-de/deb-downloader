#!/bin/bash
###################################
#         deb-downloader          #
# Copyright (C) 2018 Peter Müller #
#       https://crycode.de        #
###################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# function to display the help text
function showHelp {
  cat <<EOD
Required arguments:
 -m <mirror url>   The URL of the mirror.
 -d <dist>         Codename of the distribution.
 -p <package>      Name of the package which should be downloaded.

Optional arguments:
 -c <components>   Component(s) inside the repository. Defaults to 'main'.
 -a <architecture> Type of the processor architecture of the target system. Defaults to 'amd64'.
 -D                Detect and load all dependencies for the package.
 -t                Test run. Will only load the index files, detect the dependencies and print the download links.
 -h                Show this help.

Examples:
 Download 'nano' for Ubuntu xenial (16.04)
  $0 -m http://archive.ubuntu.com/ubuntu/ -d xenial -a amd64 -p nano

 Download 'gimp' for Ubuntu artful (17.10) using the 'universe' component
  $0 -m http://archive.ubuntu.com/ubuntu/ -d artful -c universe -a amd64 -p gimp

 Download 'ntp' for Raspbian Stretch using the default Raspbian repo settings and including all dependencies
  $0 -m http://archive.raspbian.org/raspbian/ -d stretch -c "main contrib non-free rpi" -a armhf -p ntp -D
EOD
}

# defaults
MIRROR=""
DIST=""
COMPONENTS="main"
ARCHITECTURE="amd64"
PACKAGE=""
LOAD_DEPENDS=0
TEST=0

# function to download the repository index files
function downloadIndex {
  for COMP in $COMPONENTS; do
    PACKAGES="${MIRROR}dists/${DIST}/${COMP}/binary-${ARCHITECTURE}/Packages.gz"

    LOCAL_PACKAGES="/tmp/Packages-${DIST}-${COMP}-binary-${ARCHITECTURE}"
    LOCAL_PACKAGES_GZ="$LOCAL_PACKAGES.gz"

    DOWNLOAD_PACKAGES="$PACKAGE"

    if [ -e "$LOCAL_PACKAGES" ]; then
      echo "Index for $DIST $COMP already downloaded."
    else
      wget -nv -O "$LOCAL_PACKAGES.gz" "$PACKAGES"
      if [ $? -ne 0 ]; then
        echo "!!! Download of index for $DIST $COMP failed!"
        exit 1
      fi
      gunzip $LOCAL_PACKAGES_GZ
    fi
  done
}

# function to detect the dependencies of a package
# usage: packageDepends <packagename>
function packageDepends {
  PACKAGE_NAME=$1

  for COMP in $COMPONENTS; do
    LOCAL_PACKAGES="/tmp/Packages-${DIST}-${COMP}-binary-${ARCHITECTURE}"
    DEPENDS=$(grep -Pazo "(?s)Package: $PACKAGE_NAME\n.*?\n\n" "$LOCAL_PACKAGES" | grep -Pao "^Depends: .*?$" | cut -d" " -f2-)
    [ ! -z "$DEPENDS" ] && break
  done

  if [ ! -z "$DEPENDS" ]; then
    echo "$PACKAGE_NAME depends on $DEPENDS"
  fi

  IFS=',' read -ra ADDR <<< "$DEPENDS"
  for i in "${ADDR[@]}"; do
    PKG=$(echo $i | cut -d" " -f1 | cut -d":" -f1)
    if [[ $DOWNLOAD_PACKAGES != *"$PKG"* ]]; then
      DOWNLOAD_PACKAGES="$DOWNLOAD_PACKAGES $PKG"
      packageDepends $PKG
    fi
  done
}

# function to download one package if it is not already downloaded
# usage: packageDownload <packagename>
function packageDownload {
  PACKAGE_NAME=$1

  for COMP in $COMPONENTS; do
    LOCAL_PACKAGES="/tmp/Packages-${DIST}-${COMP}-binary-${ARCHITECTURE}"
    FILENAME=$(grep -Pazo "(?s)Package: $PACKAGE_NAME\n.*?\n\n" "$LOCAL_PACKAGES" | grep -Pao "^Filename: .*?$" | cut -d" " -f2-)
    SHA256=$(grep -Pazo "(?s)Package: $PACKAGE_NAME\n.*?\n\n" "$LOCAL_PACKAGES" | grep -Pao "^SHA256: .*?$" | cut -d" " -f2-)
    [ ! -z "$FILENAME" ] && break
  done

  if [ -z $FILENAME ]; then
    echo "Package $PACKAGE_NAME not found!"
    return 1
  fi

  DOWNLOAD_LINK="${MIRROR}${FILENAME}"
  BASENAME=$(basename $FILENAME)
  if [ -e $BASENAME ]; then
    echo "File $BASENAME for $PACKAGE_NAME already downloaded."
  else
    if [ $TEST -eq 0 ]; then
      wget -nv -O $BASENAME "$DOWNLOAD_LINK"
    else
      echo "Would download $DOWNLOAD_LINK"
      return 0
    fi
  fi

  if [ $? -ne 0 ]; then
    echo "Download of $PACKAGE_NAME failed!"
    return 1
  fi

  SHA256_DL=$(sha256sum $BASENAME | cut -d" " -f1)
  if [ "$SHA256" != "$SHA256_DL" ]; then
    echo "SHA256 of $PACKAGE_NAME missmatched!"
    echo "$SHA256 != $SHA256_DL"
    return 1
  fi
}

# function for the main process
function main {
  echo "###################################"
  echo "#         deb-downloader          #"
  echo "# Copyright (C) 2018 Peter Müller #"
  echo "#       https://crycode.de        #"
  echo "###################################"
  echo

  # show help if no arguments given
  if [ -z "$1" ]; then
    showHelp
    exit 1
  fi

  # parse arguments
  while getopts ":m:d:c:a:p:Dht" opt; do
    case "$opt" in
      h  ) showHelp; exit 0;;
      m  ) MIRROR=$OPTARG;;
      d  ) DIST=$OPTARG;;
      c  ) COMPONENTS=$OPTARG;;
      a  ) ARCHITECTURE=$OPTARG;;
      p  ) PACKAGE=$OPTARG;;
      D  ) LOAD_DEPENDS=1;;
      t  ) TEST=1;;
      \? ) echo -e "Unknown option -$OPTARG\nSee $0 -h" >&2; exit 1;;
      :  ) echo "Missing option argument for -$OPTARG\nSee $0 -h" >&2; exit 1;;
      *  ) echo "Unimplemented option -$OPTARG\nSee $0 -h" >&2; exit 1;;
    esac
  done

  # check if all needed vars are set
  if [ -z "$MIRROR" ] || [ -z "$DIST" ] || [ -z "$COMPONENTS" ] || [ -z "$ARCHITECTURE" ] || [ -z "$PACKAGE" ]; then
    echo "Missing arguments! See $0 -h"
    exit 1
  fi

  echo "--- loading index"
  downloadIndex

  if [ $LOAD_DEPENDS -eq 1 ]; then
    echo "--- detect depends"
    packageDepends $PACKAGE
  fi

  echo "--- packages to load: $DOWNLOAD_PACKAGES"

  DL_OK=0
  DL_ERR=0
  DL_ERR_PACKAGES=""

  for DL in $DOWNLOAD_PACKAGES; do
    echo "--- download $DL"
    packageDownload $DL
    if [ $? -eq 0 ]; then
      echo "--- download of $DL ok"
      DL_OK=$((DL_OK+1))
    else
      echo "!!! download of $DL failed"
      DL_ERR=$((DL_ERR+1))
      DL_ERR_PACKAGES="$DL_ERR_PACKAGES $DL"
    fi
  done

  echo "----------"
  if [ $DL_ERR -eq 0 ]; then
    echo "all downloads ok :-)"
  else
    echo "$DL_OK downloads ok"
    echo "$DL_ERR downloads not ok"
    echo $DL_ERR_PACKAGES
  fi
}

main "$@"
