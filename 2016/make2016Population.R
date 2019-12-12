#
# Be wary of the KISS (Keep It Simple Stupid) assumptions and simplifications below
#


suppressWarnings(library(markovchain))
infile<-'persons/melbourne-2016-population.persons.csv.gz'

rows<-as.numeric(system(paste('gunzip -c', infile, '| wc -l'), intern=TRUE))

# sample one person from the population
gz1<-gzfile(infile, 'rt')
sample<-read.csv(gz1, nrows=1, skip = sample(rows,1), header=F, stringsAsFactors=F, strip.white=T)
header<-read.csv(gz1, nrows=1, header=F, stringsAsFactors=F, strip.white=T )
close(gz1)
person<-rbind(header,sample)

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
# Pickup/Dropoff/Deliver -> home,work,education,commercial,park
# Other -> home,work,education,commercial,park
tc<-replace(tc, tc=="Home Morning", "home")
tc<-replace(tc, tc=="Home Daytime", "home")
tc<-replace(tc, tc=="Home Night", "home")
tc<-replace(tc, tc=="Work", "work")
tc<-replace(tc, tc=="Study", "education")
tc<-replace(tc, tc=="Shop", "commercial")
tc<-replace(tc, tc=="Personal", "commercial")
tc<-replace(tc, tc=="Social/Recreational", "commercial")
# KISS: assuming Social/Recreational is equally likely to occur in commercial or park locations ; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Social/Recreational", sample(c("commercial","park"), 1))))
# KISS: assuming Pickup/Dropoff/Deliver is equally likely to occur in any location; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Pickup/Dropoff/Deliver", sample(c("home","work","education","commercial","park"), 1))))
# KISS: assuming Other is equally likely to occur in any location; improve later on; improve later on
tc<-as.vector(sapply(tc, function(x) replace(x, x=="Other", sample(c("home","work","education","commercial","park"), 1))))




#tripChainToTours(tc)
