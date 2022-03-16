
#old<-"/vol/cs/clientprojects/PlaymakerCRM/2017-09-13_PAC_Counts/"
#new<-"/vol/cs/clientprojects/PlaymakerCRM/2017-11-30_Counts/"


org<-read.hms("/vol/cs/clientprojects/PlaymakerCRM/2017-11-30_Counts/Facility_PAC_Counts.txt")
names<-colnames(org)
ranks<-names[grep("DECILE",names)]
counts<-names[grep("PATIENT",names)]
ids<-c(names[which(! names %in% ranks & ! names %in% counts)])

org2<-melt(org,id.vars=ids)
org2[,c("BUCKET","TYPE")]<-read.table(text=as.character(org2$variable),sep="_",colClasses="character")

#maybe don't use
#org3<-reshape(org2,idvar=c(ids),timevar="TYPE",direction="wide")

org3<-org2[,c("HMS_POID","BUCKET","TYPE")]
org4<-



