#Manually change date
date<-"2019_11_15"

#Run this command from main CPM folder (/vol/cs/clientprojects/CPM)
ina.settings.matches<-Sys.glob(paste("/vol/cs/clientprojects/CPM/",date,"_CPM_INAs_PxDxs/INA/CPM_INA*/config/settings.cfg",sep=""))
ina.config.matches<-Sys.glob(paste("/vol/cs/clientprojects/CPM/",date,"_CPM_INAs_PxDxs/INA/CPM_INA*/config/networkConfigSettings.tab",sep=""))
ina.claims.matches<-Sys.glob(paste("/vol/cs/clientprojects/CPM/",date,"_CPM_INAs_PxDxs/INA/CPM_INA*/config/claimSettings.tab",sep=""))


#Set up empty data objects to store data
vintage<-data.frame(vintage=as.Date(character()), stringsAsFactors=FALSE) 
upper<-data.frame(Upper_Claim=character(), stringsAsFactors=FALSE) 
lower<-data.frame(Lower_Claim=character(), stringsAsFactors=FALSE)
queue<-data.frame(Queue=character(),stringsAsFactors=FALSE)
cpm.job.name<-data.frame(CPM_Job_Name=character(),stringsAsFactors=FALSE)

sink("INA_Summary.txt")
#For each INA, print out settings
for (i in 1:length(ina.config.matches)){
  config.settings <- read.table(ina.config.matches[i],header=T,sep="\t")
  network.claim.settings <- read.table(ina.claims.matches[i],header=T,sep="\t")
  settings <- read.table(ina.settings.matches[i],as.is=T,fill=T)
  
  #Change settings file to matrix so column names aren't printed in results
  mat.settings1 <- as.matrix(settings)
  mat.settings2 <- matrix(mat.settings1, ncol = ncol(settings), dimnames = NULL)
  
  #Find needed rows in settings files
  vintage.row<-grep("VINTAGE",mat.settings2)
  upper.claim.row<-grep("UPPER",mat.settings2)
  lower.claim.row<-grep("LOWER",mat.settings2)
  queue.row<-grep("JOB_QUEUE",mat.settings2)
  cpm.jobname.row<-grep("JOB_NAME",mat.settings2)
  
  #Print summary for each INA
  cat("Network Name:", levels(config.settings$NETWORK_NAME),"\n")
  cat("\tNetwork Type:", levels(config.settings$NETWORK_TYPE),"\n")
  cat("\tVintage:",mat.settings2[vintage.row,3],"\n")
  cat("\tVendor:", levels(network.claim.settings$VENDOR_NAME),"\n")
  cat("\tSettings:", levels(network.claim.settings$SETTINGS),"\n")
  cat("\tQuarters:", levels(as.factor(config.settings$LINK_QTRS)),"\n")
  cat("\tUpper Claim Limit:",mat.settings2[upper.claim.row,3],"\n")
  cat("\tLower Claim Limit:",mat.settings2[lower.claim.row,3],"\n")
  cat("\tINA Queue:",mat.settings2[queue.row,3],"\n\n")
  
  
  #Create files with all vintages, upper claims dates, lower claims dates, and queue listed
  #Note: These variables are saved so that frequencies can be run below
  
  vintage.line<-(settings[vintage.row,3])
  vintage<-rbind(vintage,as.data.frame(vintage.line))
  vintage<-droplevels(vintage)
  
  upper.line<-(settings[upper.claim.row,3])
  upper<-rbind(upper,as.data.frame(upper.line))
  upper<-droplevels(upper)
  
  lower.line<-(settings[lower.claim.row,3])
  lower<-rbind(lower,as.data.frame(lower.line))
  lower<-droplevels(lower)
  
  queue.line<-(settings[queue.row,3])
  queue<-rbind(queue,as.data.frame(queue.line))
  queue<-droplevels(queue)
  
  #For CPM project, print job name to ensure that job name begins with "CPM_"
  cpm.jobname.row<-grep("JOB_NAME",mat.settings2)  
  cpm.jobname.line<-(settings[cpm.jobname.row,3])
  cpm.job.name<-rbind(cpm.job.name,as.data.frame(cpm.jobname.line))
  cpm.job.name<-droplevels(cpm.job.name)
     
  
}

cat("\nSUMMARY\n\n")
vintage.table<-table(vintage)
prop.table(vintage.table)*100
cat("\n")

upper.table<-table(upper)
prop.table(upper.table)*100
cat("\n")

lower.table<-table(lower)
prop.table(lower.table)*100
cat("\n")

queue.table<-table(queue)
prop.table(queue.table)*100
cat("\n")

#Prints first 4 characters of job name (all should start with "CPM_")
cpm.jobname.trunc<-strtrim(cpm.job.name$cpm.jobname.line,4)
jobname.table<-table(cpm.jobname.trunc)
prop.table(jobname.table)*100
cat("\n")

cat("Total number of INA folders:", length(ina.config.matches))

sink()
