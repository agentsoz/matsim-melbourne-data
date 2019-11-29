#!/bin/bash

DIR=$(dirname "$0")
WGET=wget

ARCHIVE=$DIR/vista_2012_16_extracted_activities_weekday.csv.gz
CODE=$DIR/vista_2012_16_functions.R
WEBARCHIVE=https://github.com/agentsoz/ees-data/blob/master/vista/VISTA_2012_16/$ARCHIVE?raw=true
WEBCODE=https://raw.githubusercontent.com/agentsoz/ees-data/master/vista/VISTA_2012_16/$CODE
OUTFILE=$DIR/vista_2012_16_extracted_activities_weekday_markov_chain_model.rds

printf "\n"

function downloadData() {
  # check if wget exists else abort
  command -v $WGET > /dev/null 2>&1 || { echo "Shell program '$WGET' not found, please install it first"; exit 0; }

  # download the processed VISTA 2012-16 weekend activities archive
  if [ ! -f $ARCHIVE ] ; then
    printf "Downloading $WEBARCHIVE to $ARCHIVE\n"
    CMD="wget -O $ARCHIVE $WEBARCHIVE"; echo $CMD && eval $CMD
  else
    printf "Found archive $ARCHIVE so will use it\n"
  fi
  # download the R utility functions for creating the markov chain
  if [ ! -f $CODE ] ; then
    printf "Downloading $WEBCODE to $CODE\n"
    CMD="wget -O $CODE $WEBCODE"; echo $CMD && eval $CMD
  else
    printf "Found archive $CODE so will use it\n"
  fi
}

function removeDownloadedData() {
  CMD="rm -f $ARCHIVE $CODE"; echo $CMD && eval $CMD
}

function createMarkovChainModel() {
  read -d '' CMD << EOL
Rscript --vanilla -e '
source("$CODE");
mc<-create_markov_chain_model("VISTA 2012-16 Weekday Activities","$ARCHIVE");
saveRDS(mc, file = "$OUTFILE")
'
EOL
  echo $CMD && eval $CMD
}

if [ ! -f $OUTFILE ] ; then
  downloadData
  createMarkovChainModel
  removeDownloadedData
else
  printf "Found markov chain model object file $OUTFILE so nothing to do\n"
fi
