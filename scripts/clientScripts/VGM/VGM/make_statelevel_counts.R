source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
library("openxlsx")


claims<-read.hms("raw_claims.tab",scanlen=8000)
indivs<-read.hms("../milestones_unproj/individuals.tab")
desc<-read.hms("../milestones_unproj/counts/raw_codes.tab")

#add state to claims
claims$STATE<-indivs$STATE[match(claims$PIID,indivs$HMS_PIID)]

#remove territories
claims<-claims[which(! claims$STATE %in% c("AE","AP","VI","GU","PR")),]

#add descriptions
claims[,"CODE DESCRIPTIONS"]<-desc$FULL[match(claims$CODE,desc$CODE)]

#CODE	CODE TYPE	CODE SCHEME	BUCKET	PRACTITIONERS	FACILITIES	PATIENTS	CLAIMS	PROCEDURES	CODE DESCRIPTION


#State<-"AK"
#Bucket<-"Lcodes"
#Code<-"L1843"


for (State in unique(claims$STATE)){
 output<-as.data.frame(matrix(ncol=10,nrow=0))
 colnames(output)<-c("CODE","CODE TYPE","CODE SCHEME","BUCKET","PRACTITIONERS","FACILITIES","PATIENTS","CLAIMS","PROCEDURES","CODE DESCRIPTION")


 #state
 temp<-claims[which(claims$STATE == State),]
 outrow<-c("ANY","ANY","ANY","ANY",length(unique(temp$PIID)),length(unique(temp$POID)),length(unique(temp$PATIENT_ID)),length(unique(temp$CLAIM_ID)),length(unique(temp$PROC_ID)),"")
 output[1,]<-outrow
 print(State)

 for (Bucket in unique(temp$BUCKET)){
  #bucket
  temp2<-temp[which(temp$BUCKET == Bucket),]
  outrow<-c("ANY","ANY","ANY",Bucket,length(unique(temp2$PIID)),length(unique(temp2$POID)),length(unique(temp2$PATIENT_ID)),length(unique(temp2$CLAIM_ID)),length(unique(temp2$PROC_ID)),"")
  output<-rbind(output,outrow)

  for (Code in unique(temp2$CODE)){
  #code
   temp3<-temp2[which(temp2$CODE == Code),]
   outrow<-c(Code,temp3[1,"BUCKET_TYPE"],temp3[1,"CODE_SCHEME"],Bucket,length(unique(temp3$PIID)),length(unique(temp3$POID)),length(unique(temp3$PATIENT_ID)),length(unique(temp3$CLAIM_ID)),length(unique(temp3$PROC_ID)),temp3[1,"CODE DESCRIPTIONS"])
   output<-rbind(output,outrow)
  }
 }

 #star out low values
 output[,c(5:9)]<-sapply(output[,c(5:9)],as.numeric)
 output[,c(5:9)]<-replace(output[,c(5:9)],output[,c(5:9)]<11,"*")

 #write out
 #write.hms(output,paste(State,"test.txt",sep="_"))
 test<-openxlsx::loadWorkbook("State_level_counts.xlsx")
 openxlsx::addWorksheet(test,State)
 openxlsx::writeData(test,State,output,colNames=T)
 openxlsx::saveWorkbook(test,"State_level_counts.xlsx",overwrite=T)

}
