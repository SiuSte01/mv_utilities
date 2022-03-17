setwd("/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx")
icd9<-read.table("Code_xwalk.txt",colClasses='character',fill=T,header=T,sep="\t")
tab<-read.table("ICD9.tab",colClasses='character',sep="\t")
colnames(tab)<-c("BUCKET","CODE","CODE_TYPE")
tab$SCHEME<-"ICD9"
tab$DESCRIPTION<-icd9$SOURCE_DESCRIPTION[match(tab$CODE,icd9$SOURCE_CODE)]
write.table(tab,"ICD9_description.tab",sep="\t", quote=F,row.names=F)
