# MATSim population for Melbourne

This script generates a sample population for Melbourne based on the [ABS 2016 census](https://www.abs.gov.au/websitedbs/censushome.nsf/home/2016) and using [VISTA-like](https://transport.vic.gov.au/about/data-and-research/vista) activities and trips.

## How to setup dependencies

To get started, download the dependency data and script files first. There are convenience bash scripts for doing this. The steps are as follows and *only have to be performed once*:

`./activities/make.sh`
`./locations/make.sh`
`./persons/make.sh`

## How to run

Here is an example of how to build a sample population of 100 persons:

```
$./make.sh

usage ./make.sh SAMPLE
    creates a sample Melbourne population based on the 2016 census
    with VISTA-like activities and trips and
    containing SAMPLE number of persons.

$./make.sh 100
Rscript --vanilla -e 'suppressPackageStartupMessages(source("make2016Population.R")); make2016MATSimMelbournePopulation(100, "mel2016popn100pax.xml")'
...
2020-01-09 12:48:04 | selecting a random sample of 100 persons from the Melbourne 2016 census population
2020-01-09 12:48:28 | generating 100 MATSim persons with VISTA-like trips
2020-01-09 12:48:29 | ..........|..........|..........|..........|..........| 50
2020-01-09 12:49:05 | ..........|..........|..........|..........|..........| 100

2020-01-09 12:49:37 | finished generating 100/100 persons
2020-01-09 12:49:37 | saving MATSim population to mel2016popn100pax.xml

```
