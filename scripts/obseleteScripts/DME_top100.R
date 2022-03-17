##Update Agency_Owners and pjp file to the current locations.

HHA_Agency_Owners<-read.table("/vol/cs/clientprojects/HHA/Agency_Owners/2017_08_02_Updates/HHA_Agency_Owners.tab", header=T,sep="\t",comment.char="",quote="",as.is=T,fill=T)
PJP_HHA<-read.table("/vol/cs/clientprojects/HHA/PJP_Files/2017-08-09/poid_joined_pos_file_hha.tab", header=T,sep="\t",comment.char="",quote="",as.is=T,fill=T)
HHA_merged<-merge(HHA_Agency_Owners, PJP_HHA,by = "HMS_POID" )
Websites<-unique(HHA_merged[,c("Agency.Owner", "Website")])
Owners_by_State<-unique(subset(HHA_merged, select = c("Agency.Owner", "STATE.x")))
Owners_POID_Count<-aggregate(cbind(HHA_merged$HMS_POID)~ HHA_merged$Agency.Owner, data=HHA_merged, FUN=length)
colnames(Owners_POID_Count)<-c("Owner", "POID_Count")
Owners_State_Count<-aggregate(cbind(Owners_by_State$STATE.x)~ Owners_by_State$Agency.Owner, data=Owners_by_State, FUN=length)
colnames(Owners_State_Count)<-c("Owner","State_Count")
Owners_Patient_Count<-aggregate(cbind(HHA_merged$PATIENT_COUNT)~ HHA_merged$Agency.Owner, data=HHA_merged, FUN=sum)
colnames(Owners_Patient_Count)<-c("Owner", "Patient_Count")
Owners_Patient_Count$Pct<-Owners_Patient_Count$Patient_Count / sum(Owners_Patient_Count$Patient_Count)
Top100<-merge(Owners_Patient_Count, Owners_POID_Count, by = "Owner")
Top100<-merge(Top100, Owners_State_Count, by = "Owner")
Top100<-merge(Top100, Websites, by.x = "Owner", by.y = "Agency.Owner")
Top100<-Top100[,c(1,3,5,4,6)]
Top100<-Top100[rev(order(Top100$Pct)),]
write.table(Top100, "Top100.tab", quote = FALSE, sep = "\t", row.names = FALSE, col.names = FALSE)

##Open Top100.tab and paste into Excel template T:\HHA\Market_Share\HHA_Owner_Ranks_template.xlsx.