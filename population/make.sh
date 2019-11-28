#!/bin/bash

DIR=$(dirname "$0")
WGET=wget
ARCHIVE=melbourne-2016-population
WEBFILE=https://github.com/agentsoz/synthetic-population/raw/master/data/$ARCHIVE.zip

printf "\n"

function getArchive() {
  # check if wget exists else abort
  command -v $WGET > /dev/null 2>&1 || { echo "Shell program '$WGET' not found, please install it first"; exit 0; }

  # download the Melbourne 2016 population if not there already
  if [ ! -f $DIR/$ARCHIVE.zip ] ; then
    printf "Downloading $WEBFILE to $DIR/$ARCHIVE.zip\n"
    wget -O $DIR/$ARCHIVE.zip $WEBFILE
  else
    printf "Found population archive $DIR/$ARCHIVE.zip so will use it\n"
  fi
}

function extractArchive() {
  # extract the archive if not already done
  if [ ! -d $DIR/$ARCHIVE ] ; then
    CMD="unzip -q -o -d $DIR/$ARCHIVE $DIR/$ARCHIVE.zip"
    printf "Extracting $DIR/$ARCHIVE.zip to directory $DIR/$ARCHIVE\n"
    echo $CMD && eval $CMD
  else
    printf "Found uncompressed population archive directory $DIR/$ARCHIVE so will use it\n"
  fi
}

# concatenate all the person level files (but add the header row only once)
OUTFILE=$DIR/$ARCHIVE.persons.csv
if [ ! -f $OUTFILE.gz ] ; then
  getArchive
  extractArchive
  find $DIR/$ARCHIVE -name "persons.csv.gz" | sort | while read file  ; do
    CMD="gzcat \"$file\" | tail -n +2  >> $OUTFILE"; echo $CMD && eval $CMD
    CMD="gzcat \"$file\" | tail -r | tail -1 > $DIR/.header"; echo $CMD && eval $CMD
  done
  CMD="mv $OUTFILE $OUTFILE.tmp"; echo $CMD && eval $CMD
  CMD="cat $DIR/.header $OUTFILE.tmp >  $OUTFILE"; echo $CMD && eval $CMD
  CMD="rm -f $OUTFILE.tmp $DIR/.header"; echo $CMD && eval $CMD
  CMD="gzip -9 $OUTFILE"; echo $CMD && eval $CMD
else
  printf "Found synthetic population file $OUTFILE.gz so nothing to do\n"
fi

# zless melbourne-2016-population/melbourne/generated/SA2/Yarraville/population/persons.csv.gz | tail -n +2 | head
