#!/usr/bin/env bash
if [ $# -ne 1 ];
    then printf "\nusage $0 SAMPLE
    creates a sample Melbourne population based on the 2016 census
    with VISTA-like activities and trips and
    containing SAMPLE number of persons.\n\n"
    exit
fi

DIR=$(dirname "$0")

SAMPLE=$1
FILENAME=mel2016popn${SAMPLE}pax.xml
read -r -d '' SCRIPT << EOM
suppressPackageStartupMessages(source("make2016Population.R"));
make2016MATSimMelbournePopulation($SAMPLE, "$FILENAME")
EOM

CMD="Rscript --vanilla -e '$SCRIPT'"
echo $CMD && eval $CMD
