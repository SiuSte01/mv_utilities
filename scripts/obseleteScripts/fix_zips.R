source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

file<-commandArgs(trailingOnly=TRUE)[1]
if(! file.exists(file)){stop("file not found")}

data<-read.hms(file)

#zipcols<-colnames(data)[grep("ZIP_",colnames(data))]
#zip4cols<-colnames(data)[grep("ZIP4_",colnames(data))]

data[which(nchar(data$ZIP_1)==3),"ZIP_1"]<-paste("00",data[which(nchar(data$ZIP_1)==3),"ZIP_1"],sep="")
data[which(nchar(data$ZIP_1)==4),"ZIP_1"]<-paste("0",data[which(nchar(data$ZIP_1)==4),"ZIP_1"],sep="")

data[which(nchar(data$ZIP_2)==3),"ZIP_2"]<-paste("00",data[which(nchar(data$ZIP_2)==3),"ZIP_2"],sep="")
data[which(nchar(data$ZIP_2)==4),"ZIP_2"]<-paste("0",data[which(nchar(data$ZIP_2)==4),"ZIP_2"],sep="")

data[which(nchar(data$ZIP4_1)==3),"ZIP4_1"]<-paste("0",data[which(nchar(data$ZIP4_1)==3),"ZIP4_1"],sep="")
data[which(nchar(data$ZIP4_1)==2),"ZIP4_1"]<-paste("00",data[which(nchar(data$ZIP4_1)==2),"ZIP4_1"],sep="")
data[which(nchar(data$ZIP4_1)==1),"ZIP4_1"]<-paste("000",data[which(nchar(data$ZIP4_1)==1),"ZIP4_1"],sep="")

data[which(nchar(data$ZIP4_2)==3),"ZIP4_2"]<-paste("0",data[which(nchar(data$ZIP4_2)==3),"ZIP4_2"],sep="")
data[which(nchar(data$ZIP4_2)==2),"ZIP4_2"]<-paste("00",data[which(nchar(data$ZIP4_2)==2),"ZIP4_2"],sep="")
data[which(nchar(data$ZIP4_2)==1),"ZIP4_2"]<-paste("000",data[which(nchar(data$ZIP4_2)==1),"ZIP4_2"],sep="")

file.copy(file,paste(file,"_original",sep=""))

write.hms(data,file)

