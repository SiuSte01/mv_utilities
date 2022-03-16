source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

all_codes<-read.hms("Code_xwalk.txt",y=c("BUCKET","CODE_TYPE","SOURCE_CODE","SOURCE_CODE_NODEC","TARGET_CODE","TARGET_CODE_NODEC","SOURCE_SCHEME","TARGET_SCHEME","SOURCE_DESCRIPTION","TARGET_DESCRIPTION"))


for (bucket in unique(all_codes$BUCKET)){
 codes<-all_codes[which(all_codes$BUCKET==bucket),]
 source<-codes[,c("SOURCE_CODE_NODEC","SOURCE_SCHEME")]
 target<-codes[,c("TARGET_CODE_NODEC","TARGET_SCHEME")]

 colnames(source)<-c("CODE","SCHEME")
 colnames(target)<-c("CODE","SCHEME")

 out<-rbind(source,target)

 out<-out[which(! duplicated(out)),]

 write.hms(out,paste(bucket,"inputs.txt",sep="_"),sep=" ")
}

