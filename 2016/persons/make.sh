#!/bin/bash

DIR=$(dirname "$0")
WGET=wget
ARCHIVE=melbourne-2016-population
WEBFILE=https://github.com/agentsoz/synthetic-population/raw/master/data/$ARCHIVE.zip

printf "\n"

function getAndExtractMelbourne2016PopulationArchive() {
  # check if wget exists else abort
  command -v $WGET > /dev/null 2>&1 || { echo "Shell program '$WGET' not found, please install it first"; exit 0; }

  # download and extract the Melbourne 2016 population if not there already
  if [ ! -f $DIR/$ARCHIVE.zip ] ; then
    printf "Downloading $WEBFILE to $DIR/$ARCHIVE.zip\n"
    CMD="wget -O $DIR/$ARCHIVE.zip $WEBFILE"; echo $CMD && eval $CMD
  else
    printf "Found population archive $DIR/$ARCHIVE.zip so will use it\n"
  fi
  printf "Extracting $DIR/$ARCHIVE.zip to directory $DIR/$ARCHIVE\n"
  CMD="unzip -q -o -d $DIR/$ARCHIVE $DIR/$ARCHIVE.zip"; echo $CMD && eval $CMD
}

OUTFILE=$DIR/$ARCHIVE.persons.csv
if [ ! -f $OUTFILE.gz ] ; then
  getAndExtractMelbourne2016PopulationArchive
  find $DIR/$ARCHIVE -name "persons.csv.gz" | sort | while read file  ; do
    CMD="gunzip -c \"$file\" | tail -n +2  >> $OUTFILE"
    echo $CMD && eval $CMD
    CMD="gunzip -c \"$file\" | tail -r | tail -1 > $DIR/.header"
    echo $CMD && eval $CMD
  done
  CMD="mv $OUTFILE $OUTFILE.tmp"; echo $CMD && eval $CMD
  CMD="cat $DIR/.header $OUTFILE.tmp >  $OUTFILE"; echo $CMD && eval $CMD
  CMD="rm -rf $OUTFILE.tmp $DIR/.header $DIR/$ARCHIVE.zip $DIR/$ARCHIVE"
  echo $CMD && eval $CMD
  CMD="gzip -9 $OUTFILE"; echo $CMD && eval $CMD
else
  printf "Found synthetic population file $OUTFILE.gz so nothing to do\n"
fi
