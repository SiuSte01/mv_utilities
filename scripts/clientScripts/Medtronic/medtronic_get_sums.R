source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
data<-data.frame(matrix(ncol=2,nrow=0))
colnames(data)<-c("Service_Line","Total_Claims")

for (i in Sys.glob("*/QA/organizations.tab")){
 name<-strsplit(i,split="/")[[1]][1]
 temp<-read.hms(i)
 claims<-grep("CLAIMS",colnames(temp))
 value<-sum(temp[,claims],na.rm=T)
 data<-rbind(data,as.data.frame(t(c("Service_Line"=name,"Total_Claims"=value))))
}

write.hms(data,"spine_total_claims.tab")
