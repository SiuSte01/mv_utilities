#Run from main PxDx folder

#Recursive search for all claimSettings files
matches.vendor<-list.files(pattern='jobVendorSettings.tab',recursive=TRUE,full.names=TRUE)
matches.settings<-list.files(pattern='settings.cfg',recursive=TRUE,full.names=TRUE)


#Exclude files from the cloning directory and print list
pxdx.vendor.matches <- grep(pattern='PxDx/config/', matches.vendor, value = TRUE)
# pxdx.settings.matches <- grep(pattern='PxDx/config/', matches.settings, value = TRUE)
pxdx.settings.matches <- grep(pattern='*/config/', matches.settings, value = TRUE)


#Set up empty data objects to store data
#vintage<-data.frame(vintage=as.Date(character()), stringsAsFactors=FALSE) 
vintage<-data.frame(vintage=as.Date(character()), stringsAsFactors=FALSE) 
queue<-data.frame(Queue=character(),stringsAsFactors=FALSE)
database<-data.frame(Database=character(),stringsAsFactors=FALSE)


sink("PxDx_Summary.txt")
#For each PxDx, print out settings
for (i in 1:length(pxdx.vendor.matches)){
 jobvendorsettings <- read.table(pxdx.vendor.matches[i],header=T,sep="\t")
 settings <- read.table(pxdx.settings.matches[i],as.is=T,fill=T)
 
 #Change settings file to matrix so column names aren't printed in results
 mat.settings1 <- as.matrix(settings)
 mat.settings2 <- matrix(mat.settings1, ncol = ncol(settings), dimnames = NULL)
 
 #Find needed rows in settings files
 vintage.row<-grep("VINTAGE",mat.settings2)
 job.name.row<-grep("JOB_NAME",mat.settings2)
 database.row<-grep("CLAIMS_DATABASE",mat.settings2)
 queue.row<-grep("JOB_QUEUE",mat.settings2)
 
 
  #Print summary for each INA
 cat("Job Name:", mat.settings2[job.name.row,3],"\n")
 cat("\tVintage:",mat.settings2[vintage.row,3],"\n")
 cat("\tClaims Database:",mat.settings2[database.row,3],"\n")
 cat("\tSettings:", levels(jobvendorsettings$SETTINGS),"\n")
 cat("\tCount:", levels(jobvendorsettings$COUNT_TYPE),"\n")
 cat("\tQueue:",mat.settings2[queue.row,3],"\n\n")


 #Create files with all vintages, queues, and databases listed
 #Note: These variables are saved so that frequencies can be run below

 vintage.line<-(settings[vintage.row,3])
 vintage<-rbind(vintage,as.data.frame(vintage.line))
 vintage<-droplevels(vintage)
 
 queue.line<-(settings[queue.row,3])
 queue<-rbind(queue,as.data.frame(queue.line))
 queue<-droplevels(queue)
 
 database.line<-(settings[database.row,3])
 database<-rbind(database,as.data.frame(database.line))
 database<-droplevels(database)
 
}

cat("\nSUMMARY\n\n")
vintage.table<-table(vintage)
prop.table(vintage.table)*100
cat("\n")

queue.table<-table(queue)
prop.table(queue.table)*100
cat("\n")


database.table<-table(database)
prop.table(database.table)*100
cat("\n")

cat("Total number of PxDx folders:", length(pxdx.settings.matches))

sink()
