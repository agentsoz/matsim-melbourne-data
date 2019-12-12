samplePersons <- function(sampleSize = NULL) {
  #sampleSize<-10 #for testing purposes
  infile<-'persons/melbourne-2016-population.persons.csv.gz'
  
  # default sample size is the full set
  rows<-as.numeric(system(paste('gunzip -c', infile, '| wc -l'), intern=TRUE))
  if (is.null(sampleSize)) {
    sampleSize = rows
  }

  # get the csv header
  gz1<-gzfile(infile, 'rt')
  header<-read.csv(gz1, nrows=1, header=F, stringsAsFactors=F, strip.white=T )
  close(gz1)

  # read in the population
  gz1<-gzfile(infile, 'rt')
  all<-read.csv(gz1, header=F, stringsAsFactors=F, strip.white=T )
  close(gz1)

  # sample the required number of persons from the population
  if (sampleSize == rows) {
    sampleSet = all
  } else {
    sampleSet<-all[1+sample(nrow(all)-1, sampleSize),] # sample any but the header rows
  }
  
  colnames(sampleSet)<-header
  sampleSet<-sampleSet[order(rownames(sampleSet)),]
  return(sampleSet)
}
