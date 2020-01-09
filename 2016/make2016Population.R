#
# Be wary of KISS (Keep It Simple Stupid) assumptions and simplifications below
#

suppressWarnings(library(markovchain))
suppressWarnings(library(XML))
suppressWarnings(source('persons/samplePersons.R'))
suppressWarnings(source('locations/importData.R'))

make2016MATSimMelbournePopulation <- function(sampleSize, xmlfile) {
  
  # internal function to create a trip chain for a person
  generateTripChain<-function(mc, SA1) {
    
    # internal function to general the trip chain
    # TODO: SA1 has no bearing yet on the trip chain produced
    generateChain<-function(mc, SA1) {
      v<-c("Home Morning",rmarkovchain(n=100,mc,t0="Home Morning")) # chain of requested length
      idx<-match("Home Night", v); # find index of last activity 
      v<-v[seq(1,idx)] # remove repeating last activities
      return(v)
    }
    
    # internal function to replace activity tags with location tags
    replaceActivityWithLocationTags<-function (tc) {
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
      return(tc)
    }
    
    # generate a new trip chain
    tc<-generateChain(mc, null)
    # For any chain with 'With Someone' discard and start again as we do not care about generating secondary persons
    while("With Someone" %in% tc) {
      tc<-generateChain(mc, null)
    }
    # KISS: Discarding trip chains with 'Mode Change' for now; improve later on
    while("Mode Change" %in% tc) {
      tc<-generateChain(mc, null)
    }
    
    # TODO: remove successive home activities
    # ...
    
    # replace activity tags with location tags
    tc<-replaceActivityWithLocationTags(tc)
    return(tc)
  }
  
  # split trip into tours
  # order of extraction of tours is: home, then work, then others
  # tripChainToTours<-function(tc) {
  # }
  
  # Function to create activities and legs from given trip chain
  createMATSimActivitiesAndLegs <- function(person, tc) {
    # get a person and determine its home SA1 and coordinates
    home_sa1<-as.character(person$SA1_MAINCODE_2016)
    home_xy<-getAddressCoordinates(home_sa1,"home")
    if(is.null(home_xy)) return(NULL)
    
    # data frames for storing this person's activities and connecting legs
    acts<-data.frame(act_id=NA, type=NA, sa1=NA, x=NA, y=NA, start_hhmmss=NA, end_hhmmss=NA)
    legs<-data.frame(origin_act_id=NA,mode=NA,dest_act_id=NA)
    
    # first activity is always home
    if (tc[1] != "home") stop(paste0('First activity in trip chain must be `home` but was `',tc[1],'`'))
    acts[1,]$act_id<-1
    acts[1,]$type<-"home"
    acts[1,]$sa1<-home_sa1
    acts[1,]$x<-home_xy[1]
    acts[1,]$y<-home_xy[2]
    acts[1,]$start_hhmmss<-"06:00:00" # TODO: set sensible start/end times
    acts[1,]$end_hhmmss<-"06:00:00" # TODO: set sensible start/end times
    # determine the SA1 and coordinartes for the remaining activites
    mode<-NULL
    work_sa1<-NULL; work_xy<-NULL
    for(i in 2:length(tc)) {
      acts[i,]$act_id<-i
      acts[i,]$type<-tc[i]
      # determine SA1 for this activity type given last SA1
      if (is.null(mode) || tc[i-1]=="home") { # mode can change if last activity was home
        df<-findLocation(acts[i-1,]$sa1,acts[i,]$type)
      } else {
        df<-findLocationKnownMode(acts[i-1,]$sa1, acts[i,]$type, mode)
      }
      # assign the SA1 and coords
      if(tc[i]=="home") { # re-use home SA1 and coords
        acts[i,]$sa1<-home_sa1 
        acts[i,]$x<-home_xy[1]
        acts[i,]$y<-home_xy[2]
      } else if(tc[i]=="work" && !is.null(work_sa1)) { # re-use work SA1 and coords
        acts[i,]$sa1<-work_sa1
        acts[i,]$x<-work_xy[1]
        acts[i,]$y<-work_xy[2]
      } else {
        acts[i,]$sa1<-df[2]
        xy<-getAddressCoordinates(acts[i,]$sa1,acts[i,]$type)
        if(is.null(xy)) return(NULL)
        acts[i,]$x<-xy[1]
        acts[i,]$y<-xy[2]
        # if this is a work activity then also save its SA1 and XY coordinates for future re-use
        if(tc[i]=="work" && is.null(work_sa1)) {
          work_sa1<-df[2]
          work_xy<-xy
        }
      }
      
      # TODO: assign sensible start and end times for activities
      acts[i,]$start_hhmmss<-"06:00:00"
      acts[i,]$end_hhmmss<-"06:00:00"
      
      # save the leg
      mode=df[1]
      legs[i-1,]$origin_act_id<-acts[i-1,]$act_id
      legs[i-1,]$dest_act_id<-acts[i,]$act_id
      legs[i-1,]$mode<-mode
    }
    rownames(acts)<-seq(1:nrow(acts))
    rownames(legs)<-seq(1:nrow(legs))
    return(list(acts,legs))
  }
  
  # Function to generate MATSim person XML
  generateMATSimPersonXML <- function(pid, p, acts, legs) {
    
    
    ### internal function to generate MATSim person attributes
    attachMATSimPersonAttributes <- function(pp,p) {
      attrs<-drop(as.matrix(p)) # get named vector of attributes
      # create person attributes
      xattr<-lapply(
        seq_along(attrs),
        function(i,x,n) { 
          xx<-newXMLNode("attribute", attrs=c(name = n[[i]], class="java.lang.String"))
          xmlValue(xx)<-x[[i]]
          xx
        }, 
        x=attrs, 
        n=names(attrs))
      # assign attribute list to attributes tag
      xattrs<-newXMLNode("attributes")
      addChildren(xattrs,xattr) 
      # attach attributes to person
      addChildren(pp,xattrs) 
      return(pp)
    }
    
    ### internal function to generate MATSim person plan of activities and legs
    attachMATSimPersonPlanXML<- function(pp, acts, legs) {
      # create the activities
      xacts<-apply(
        acts, 1,
        function(x) {
          n<-newXMLNode("activity", attrs=c(type=x[[2]], x=x[[4]], y=x[[5]], end_time=x[[7]]))
        })
      # create the legs
      xlegs<-apply(
        legs, 1,
        function(x) { 
          n<-newXMLNode("leg", attrs=c(x[2]))
          n
        })
      #interleave the activities and legs
      idx <- order(c(seq_along(xacts), seq_along(xlegs)))
      xactslegs<-(c(xacts,xlegs))[idx]
      #create a new plan
      xplan<-newXMLNode("plan", attrs=c(selected="yes"))
      # attach the activities and legs to the plan
      addChildren(xplan,xactslegs)
      #attach plan to person
      addChildren(pp,xplan)
      return(pp)  
    }
    
    # new XML node for this person
    pp<-newXMLNode("person", attrs=c(id=pid))
    # attach person attributes to XML node
    pp<-attachMATSimPersonAttributes(pp,p) 
    # attach plan with activities and legs to XML node
    pp<-attachMATSimPersonPlanXML(pp, acts, legs)
    # return the XML node
    return(pp)
  }  
  
  # sample trip chain for testing
  #tc<-c("Home Morning", "Pickup/Dropoff/Deliver", "Home Daytime", "Social/Recreational",    
  #      "Social/Recreational", "Home Daytime", "Pickup/Dropoff/Deliver", "Pickup/Dropoff/Deliver", "Home Night")
  # tc<-c(
  #   "Home Morning",           "Shop",                   "Social/Recreational",    "Home Daytime",          
  #   "Pickup/Dropoff/Deliver", "Home Daytime",           "Shop",                   "Home Daytime",          
  #   "With Someone",           "Home Daytime",           "Pickup/Dropoff/Deliver", "Shop",                  
  #   "Home Daytime",           "Shop",                   "Work",                   "Home Night"  
  # )
  
  
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  
  printProgress<-function(row, char) {
    if((row-1)%%50==0) echo('')
    cat(char)
    if(row%%10==0) cat('|')
    if(row%%50==0) cat(paste0(' ', row,'\n'))
  }
  
  # sample N persons from the population
  getPersons<-function(n) {
    orig<-samplePersons(n)
    persons<-assignSa1Maincode(orig)
    persons<-as.data.frame(persons)
  }
  
  # save log
  sink(paste0(xmlfile,".log"), append=FALSE, split=TRUE) # sink to both console and log file
  
  # number of persons to create
  cat('\n')
  echo(paste0('selecting a random sample of ', sampleSize, ' persons from the Melbourne 2016 census population\n'))
  persons<-getPersons(sampleSize)
  
  # Read the markov chain model for trip chains
  mc<-readRDS('./activities/vista_2012_16_extracted_activities_weekday_markov_chain_model.rds')
  
  # create MATSim population XML
  doc <- newXMLDoc()
  echo(paste0('generating ', sampleSize, ' MATSim persons with VISTA-like trips\n'))
  popn<-newXMLNode("population", doc=doc)
  discarded<-persons[FALSE,]
  allacts<-NULL; alllegs<-NULL;
  for (row in 1:nrow(persons)) {
    error=FALSE
    # get the person
    p<-persons[row,]
    pid<-row-1
    # generate a trip chain for this person
    tc<-generateTripChain(mc,p$SA1_MAINCODE_2016)
    # build activities and legs for the person
    df<-createMATSimActivitiesAndLegs(p, tc)
    if(is.null(df)) return(NULL)
    acts<-df[[1]]
    legs<-df[[2]]
    # also save all activities and legs for outputting to CSV
    if (is.null(allacts)) allacts<-acts[FALSE,]
    if (is.null(alllegs)) alllegs<-legs[FALSE,]
    allacts<-rbind(allacts,cbind(personId=pid,acts));
    alllegs<-rbind(alllegs,cbind(personId=pid,legs));
    # generate MATSim XML for this person
    pp<-generateMATSimPersonXML(pid, p, acts, legs)
    if(is.null(pp)) { 
      # can be NULL sometimes if type of location required for some activiy in chain cannot be found in given SA1
      discarded<-rbind(discarded,p)
      error=TRUE
      printProgress(row,'x')
    } else {
      # attach this person to the population
      addChildren(popn,pp)
      printProgress(row,'.')
    }
  }
  cat('\n')
  echo(paste0('finished generating ',sampleSize-nrow(discarded),'/',sampleSize,' persons\n'))
  if(nrow(discarded)>0) {
    xx<-discarded[,c("AgentId","Age","Gender","RelationshipStatus","SA1_MAINCODE_2016")]
    echo('following ',nrow(discarded),' persons were discarded as suitable locations for activities could not be assigned\n')
    cat(show(xx))
  }
  outfile<-paste0(xmlfile,'.acts.csv')
  echo(paste0('saving MATSim population activities as CSV to ', outfile , '\n'))
  write.csv(allacts, file=outfile, quote=FALSE)
  outfile<-paste0(xmlfile,'.legs.csv')
  echo(paste0('saving MATSim population legs as CSV to ', outfile, '\n'))
  write.csv(alllegs, file=outfile, quote=FALSE)
  
  echo(paste0('saving MATSim population to ', xmlfile, '\n'))
  sink() # end the diversion
  # save using cat since direct save using saveXML loses formatting
  cat(saveXML(doc, 
              prefix=paste0('<?xml version="1.0" encoding="utf-8"?>\n',
                            '<!DOCTYPE population SYSTEM "http://www.matsim.org/files/dtd/population_v6.dtd">')),
      file=xmlfile)
  
}
