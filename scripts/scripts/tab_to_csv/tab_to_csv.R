args = commandArgs(trailingOnly=TRUE)
file=args[1]

source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

tab<-read.hms(file)

name<-basename(file)

name<-paste(strsplit(name,"\\.")[[1]][1],".csv",sep="")

write.csv(tab,name,na="",row.names=F)

