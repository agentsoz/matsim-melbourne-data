#!/bin/bash

DIR=$(dirname "$0")
WGET=wget

# check if wget exists else abort
command -v $WGET > /dev/null 2>&1 || { echo "Shell program '$WGET' not found, please install it first"; exit 0; }

function getfile() {
  url=$1
  tofile=$2
  if [ ! -f "$tofile" ] ; then
    printf "Downloading $url to $tofile\n"
    CMD="wget -O \"$tofile\" \"$url\""; echo "$CMD" && eval "$CMD"
  else
    printf "Found $tofile so will use it\n"
  fi
}

printf "\n"

getfile "https://cloudstor.aarnet.edu.au/plus/s/Ev2HoKbckrMiHVJ/download?path=%2F&files=SA1_attributed.sqlite" "$DIR/SA1_attributed.sqlite"

getfile "https://cloudstor.aarnet.edu.au/plus/s/Ev2HoKbckrMiHVJ/download?path=%2F&files=valid_addresses.sqlite" "$DIR/valid_addresses.sqlite"

getfile "https://cloudstor.aarnet.edu.au/plus/s/Ev2HoKbckrMiHVJ/download?path=%2F&files=distanceMatrix.rds" "$DIR/distanceMatrix.rds"

getfile "https://cloudstor.aarnet.edu.au/plus/s/Ev2HoKbckrMiHVJ/download?path=%2F&files=distanceMatrixIndex.csv" "$DIR/distanceMatrixIndex.csv"
