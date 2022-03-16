source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
args = commandArgs(trailingOnly=TRUE)

infile<-args[1]
outfile<-args[2]
cols<-args[3]

data<-read.csv(infile,header=T,stringsAsFactors=F,sep="\t",colClasses="character")

for (i in unlist(strsplit(cols,split=" "))){
 print(i)
 data[[i]]<-gsub("-","",data[[i]])
}

write.hms(data,outfile)

