#
# Be wary of KISS (Keep It Simple Stupid) assumptions and simplifications below
#

suppressWarnings(library(markovchain))
source('persons/samplePersons.R')
source('locations/importData.R')

# sample N persons from the population
orig<-samplePersons(1000)
persons<-assignSa1Maincode(orig)
persons<-as.data.frame(persons)
# Read the markov chain model for trip chains
mc<-readRDS('./activities/vista_2012_16_extracted_activities_weekday_markov_chain_model.rds')


# create a trip chain for a person
generateTripChain<-function(mc, SA1) {
  v<-c("Home Morning",rmarkovchain(n=100,mc,t0="Home Morning")) # chain of requested length
  idx<-match("Home Night", v); # find index of last activity 
  v<-v[seq(1,idx)] # remove repeating last activities
  v
}

# split trip into tours
# order of extraction of tours is: home, then work, then others
tripChainToTours<-function(tc) {
  
}

# Generate a new trip chain
tc<-generateTripChain(mc, null)

# For any chain with 'With Someone' discard and start again as we do not care about generating secondary persons
while("With Someone" %in% tc) {
  tc<-generateTripChain(mc, null)
}
# KISS: Discarding trip chains with 'Mode Change' for now; improve later on
while("Mode Change" %in% tc) {
  tc<-generateTripChain(mc, null)
}

# use this sample for now testing
#tc<-c("Home Morning", "Pickup/Dropoff/Deliver", "Home Daytime", "Social/Recreational",    
#      "Social/Recreational", "Home Daytime", "Pickup/Dropoff/Deliver", "Pickup/Dropoff/Deliver", "Home Night")
tc<-c(
  "Home Morning",           "Shop",                   "Social/Recreational",    "Home Daytime",          
  "Pickup/Dropoff/Deliver", "Home Daytime",           "Shop",                   "Home Daytime",          
  "With Someone",           "Home Daytime",           "Pickup/Dropoff/Deliver", "Shop",                  
  "Home Daytime",           "Shop",                   "Work",                   "Home Night"  
)

# convert activity-based tags to location-based tags (from SA1_attributes.sqlite) being: 
# Home* -> home
# Work -> work
# Study -> education
# Shop -> commercial
# Personal -> commercial
# Social/Recreational -> commercial,park
# Pickup/Dropoff/Deliver -> work,education,commercial,park (but not home)
# Other -> work,education,commercial,park (but not home)
tc<-replace(tc, tc=="Home Morning", "home")
tc<-replace(tc, tc=="Home Daytime", "home")
tc<-replace(tc, tc=="Home Night", "home")
tc<-replace(tc, tc=="Work", "work")
tc<-replace(tc, tc=="Study", "education")
tc<-replace(tc, tc=="Shop", "commercial")
tc<-replace(tc, tc=="Personal", "commercial")
tc<-replace(tc, tc=="Social/Recreational", "commercial")

# KISS: replace 'With Someone' with Other for now
tc<-replace(tc, tc=="With Someone", "Other")
# KISS: assuming Social/Recreational is equally likely to occur in commercial or park locations ; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Social/Recreational", sample(c("commercial","park"), 1))))
# KISS: assuming Pickup/Dropoff/Deliver is equally likely to occur in any location; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Pickup/Dropoff/Deliver", sample(c("work","education","commercial","park"), 1))))
# KISS: assuming Other is equally likely to occur in any location; improve later on; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Other", sample(c("work","education","commercial","park"), 1))))


# TODO: remove successive home activities
# ...

# get a person and determine its home SA1 and coordinates
p<-persons[1,]
home_sa1<-as.character(p$SA1_MAINCODE_2016)
home_xy<-getAddressCoordinates(acts[1,]$sa1,"home")

# data frames for storing this person's activities and connecting legs
acts<-data.frame(id=NA, type=NA, sa1=NA, x=NA, y=NA, start_hhmm=NA, end_hhmm=NA)
legs<-data.frame(origin_act_id=NA,mode=NA,dest_act_id=NA)

# first activity is always home
if (tc[1] != "home") stop(paste0('First activity in trip chain must be `home` but was `',tc[1],'`'))
acts[1,]$id<-1
acts[1,]$type<-"home"
acts[1,]$sa1<-home_sa1
acts[1,]$x<-home_xy[1]
acts[1,]$y<-home_xy[2]
# determine the SA1 and coordinartes for the remaining activites
mode<-NULL
work_sa1<-NULL; work_xy<-NULL
for(i in 2:length(tc)) {
  acts[i,]$id<-i
  acts[i,]$type<-tc[i]
  # determine SA1 for this activity type given last SA1
  if (is.null(mode) || tc[i-1]=="home") { # mode can change if last activity was home
    df<-findLocation(acts[i-1,]$sa1,acts[i,]$type)
    cat(paste0('new mode from act ',acts[i-1,]$id,'->',acts[i,]$id, ' is ', df[1], '\n'))
  } else {
    df<-findLocationKnownMode(acts[i-1,]$sa1, acts[i,]$type, mode)
  }
  # if this is a work activity then also save its SA1 and XY coordinates for future re-use
  if(tc[i]=="work" && is.null(work_sa1)) {
    work_sa1<-df[2]
    work_xy<-xy
  }
  # assign the SA1 and coords
  if(tc[i]=="home") { # re-use home SA1 and coords
    acts[i,]$sa1<-home_sa1 
    acts[i,]$x<-home_xy[1]
    acts[i,]$y<-home_xy[2]
  } else if(tc[i]=="work") { # re-use work SA1 and coords
    acts[i,]$sa1<-work_sa1
    acts[i,]$x<-work_xy[1]
    acts[i,]$y<-work_xy[2]
  } else {
    acts[i,]$sa1<-df[2]
    xy<-getAddressCoordinates(acts[i,]$sa1,acts[i,]$type)
    acts[i,]$x<-xy[1]
    acts[i,]$y<-xy[2]
  }
  # save the leg
  mode=df[1]
  legs[i-1,]$origin_act_id<-acts[i-1,]$id
  legs[i-1,]$dest_act_id<-acts[i,]$id
  legs[i-1,]$mode<-mode
}


#tripChainToTours(tc)

