source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

codelist<-read.hms("codeGroupFileTypeDescriptions.tab")
hcpcs<-codelist[which(codelist$TYPE_DESCRIPTION=="HCPCS"),]
oracle()




