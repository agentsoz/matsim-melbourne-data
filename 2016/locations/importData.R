suppressWarnings(library(sf)) # for spatial things
suppressWarnings(library(dplyr)) # for manipulating data
suppressWarnings(library(scales)) # for scaling datasets

# Read in the distance matrix. This matrix is symmetric so it doesn't matter if
# you do lookups by column or row.
distanceMatrix <- readRDS(file="locations/distanceMatrix.rds")

# Some SA1s ended up snapping their centroid to the same node in the road
# network so we need to use an index.
distanceMatrixIndex <- read.csv("locations/distanceMatrixIndex.csv")

# Reading in the attributed SA1 regions. I'm removing the geometry since it
# won't be used here. Joining with the distance matrix index so the regions are
# in the correct order.
SA1_attributed <- inner_join(distanceMatrixIndex,
                             st_read("locations/SA1_attributed.sqlite"),
                             by=c("sa1_main16"="sa1_mainco")) %>%
  dplyr::select(-GEOMETRY)

# Reading in the addresses. I'm removing the geometry and converting it to X,Y.
# These coordinates are in EPSG:7845, which is a projected coordinate system.
addresses <- st_read("locations/valid_addresses.sqlite")
addresses <- cbind(st_drop_geometry(addresses),
                   st_coordinates(addresses))

# This returns a dataframe with possible SA1_ids and their probabilities.
# There are three probabilites returned:
# 1: distProb. The probability of choosing a destination based on distance.
# 2: attractProb. The probability of choosing a destination based on that
#                 destination's attractiveness.
# 3: combinedProb. The combined probability of choosing a destination based on
#                  distance and destination attractiveness. Distance is
#                  currently weighted 4x higher since distance probability is a
#                  lot more spread out.
calculateProbabilities <- function(SA1_id,destination_category,mode) {
  # SA1_id=20604112202
  # destination_category="commercial"
  # mode="car"
  
  index <- distanceMatrixIndex %>%
    filter(sa1_main16 == SA1_id) %>%
    pull(index)
  distances <-data.frame(index=1:10244,
                         distance=distanceMatrix[index,]) %>%
    inner_join(distanceMatrixIndex, by=c("index"="index")) %>%
    pull(distance)
  
  modeMean <- NULL
  modeSD <- NULL
  if(mode=="walk"){
    modeMean <- filter(SA1_attributed,sa1_main16==SA1_id)$walking_mean
    modeSD <- filter(SA1_attributed,sa1_main16==SA1_id)$walking_sd
  }
  if(mode=="car"){
    modeMean <- filter(SA1_attributed,sa1_main16==SA1_id)$driving_mean
    modeSD <- filter(SA1_attributed,sa1_main16==SA1_id)$driving_sd
  }
  if(mode=="pt"){
    modeMean <- filter(SA1_attributed,sa1_main16==SA1_id)$pt_mean
    modeSD <- filter(SA1_attributed,sa1_main16==SA1_id)$pt_sd
  }
  if(mode=="bike"){
    modeMean <- filter(SA1_attributed,sa1_main16==SA1_id)$bicycle_mean
    modeSD <- filter(SA1_attributed,sa1_main16==SA1_id)$bicycle_sd
  }
  
  attractionProbDensity <- SA1_attributed[,match(destination_category,colnames(SA1_attributed))] %>%
    rescale(to=c(0,1))
  attractionProbability <- attractionProbDensity/sum(attractionProbDensity, na.rm=TRUE) #normalising here so the sum of the probabilities equals 1

  distProbDensity <- dnorm(distances,mean=modeMean,sd=modeSD)
  distProbDensity[is.na(attractionProbDensity)] <- NA # We aren't considering regions with no valid destination types
  distProbability <- distProbDensity/sum(distProbDensity, na.rm=TRUE) # normalising here so the sum of the probabilities equals 1

  # I've set distance probability to 4x more important than destination 
  # attraction. This is arbitrary.
  combinedDensity <- 4*distProbability+attractionProbability
  combinedProbability <- combinedDensity/sum(combinedDensity, na.rm=TRUE) # normalising here so the sum of the probabilities equals 1
  probabilityDF <- data.frame(sa1_main16=SA1_attributed$sa1_main16,
                              distProb=distProbability,
                              attractProb=attractionProbability,
                              combinedProb=combinedProbability) %>%
    filter(!is.na(combinedProb))
  return(probabilityDF)
}

# This will be made more detailed later, and actually take destination category
# into account.
chooseMode <- function(SA1_id,destination_category) {
  # SA1_id=20604112202
  # destination_category="commercial"
  
  modeProbability <- SA1_attributed %>%
    filter(sa1_main16==SA1_id) %>%
    dplyr::select(bicycle_proportion:walking_proportion) %>%
    unlist()
  modeProbabilityDF <- data.frame(mode=c("bike","car","pt","walk"),
                                  modeProbability,
                                  stringsAsFactors=FALSE)
  return(sample(modeProbabilityDF$mode, size=1,
                prob=modeProbabilityDF$modeProbability))
}

# Find a destination SA1 given a source SA1 and destination category
findLocation <- function(SA1_id,destination_category) {
  mode <- chooseMode(SA1_id,destination_category)
  probabilityDF <- calculateProbabilities(SA1_id,destination_category,mode)
  destinationSA1 <- sample(probabilityDF$sa1_main16, size=1,
                           prob=probabilityDF$combinedProb)
  return(c(mode,destinationSA1))
}

# Assuming the transport mode is restricted, this will find a destination SA1
findLocationKnownMode <- function(SA1_id,destination_category,mode) {
  probabilityDF <- calculateProbabilities(SA1_id,destination_category,mode)
  destinationSA1 <- sample(probabilityDF$sa1_main16, size=1,
                           prob=probabilityDF$combinedProb)
  return(c(mode,destinationSA1))
}

# Determine the chances of returning home for a given destination and transport mode
getReturnProbability <- function(source_SA1,destination_SA1,destination_category,mode) {
  # source_SA1=20604112202
  # destination_SA1=20604112210
  # destination_category="commercial"
  mode="car"
  probabilityDF <- calculateProbabilities(destination_SA1,destination_category,mode)
  sourceProb <- probabilityDF %>%
    filter(sa1_main16==source_SA1) %>%
    pull(distProb) # Note that we only use the distance probability here, not
                   # the combined probability.
  sourceProb <- sourceProb*nrow(probabilityDF)
  # multiplying by the number of possible regions to give the proportion of
  # choosing that region, where > 1 is more likely than choosing the region
  # completely at random.
  # The idea being that a value > 1 means that it's suitable.
  return(sourceProb)
}

# Assign coordinates to a location within a specified SA1 with a specified category 
getAddressCoordinates <- function(SA1_id,destination_category) {
  # SA1_id=20604112202
  # destination_category="commercial"
  potentialAddresses <- addresses %>%
    filter(sa1_main16==SA1_id & category==destination_category) %>%
    mutate(id=row_number())
  if(nrow(potentialAddresses)==0) return(NULL);
  address_id <- sample(potentialAddresses$id, size=1,
                    prob=potentialAddresses$count)
  address_coordinates <- potentialAddresses %>%
    filter(id==address_id) %>%
    dplyr::select(X,Y) %>%
    unlist()
  return(address_coordinates)
}




# EXAMPLES

# A dataframe of suitable homes for each SA1 along with the total number of 
# unique addresses.
suitableHomes <- addresses %>%
  filter(category=="home") %>%
  group_by(sa1_main16) %>%
  summarise(count=sum(count)) %>%
  ungroup()

# Here, we're finding a commercial destination starting in SA1 20604112202
test <- findLocation(20604112202,"commercial")

# We then try to find the probability of returning to this destination.
# Could do a loop with findLocation to iterate until this is > 1.
returnProb <- getReturnProbability(20604112202,test[2],"home",test[1])

# Assign our locations coordinates. This will break if there's no addresses
# for your specified category within the SA1 region!!!
originCoordinates <- getAddressCoordinates(20604112202,"home")
destinationCoordinates <- getAddressCoordinates(test[2],"commercial")



