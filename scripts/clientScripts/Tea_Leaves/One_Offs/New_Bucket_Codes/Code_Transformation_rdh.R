library("reshape2")

#Read in sub-bucket and parent bucket files and concatenate
sub<-read.delim("subbucket.txt",header=T,sep="\t",na.strings="")
parent<-read.delim("parent_bucket.txt",header=T,sep="\t",na.strings="")
comb<-rbind(sub,parent)

#Add columns where we know that settings will all be the same
comb$Count<-"PATIENT"
comb$Claims_Database<-"Enhanced"
comb$Workload<-"Exact"
comb$Practitioner_Roles<-"Operating,Attending,Other"
comb$Bucket_Type<-"Single"

#Read in INA settings and merge with concatenated codes file
ina_settings<-read.delim("ina_summary.txt",header=T,sep="\t",na.strings="")
comb_ina<-merge(comb,ina_settings,all.x=T)

#Adjust so that for all INAs: INAB_Settings=All, Quarters=2, and 
# (Upper Patient Age, Lower Patient Age, Pt Gender) remain blank

comb_ina$INAB_Settings[which(! is.na(comb_ina$Network_Type))]<-"All"
comb_ina$Quarters[which(! is.na(comb_ina$Network_Type))]<-2
comb_ina$Upper_Patient_Age<-NA
comb_ina$Lower_Patient_Age<-NA
comb_ina$Pt_Gender<-NA

#Transform codes file based on DORY settings
comb_ina_melt<-melt(comb_ina,id.vars=c("Parent_Bucket","Sub_Bucket","Type","Code","Code_Description","Scheme","Count","Claims_Database","Workload","Practitioner_Roles","Bucket_Type","Network_Type","Relationship_Type","INAB_Settings","Quarters","Upper_Patient_Age","Lower_Patient_Age","Pt_Gender"),na.rm=T)

#adding a column to differentiate parent from subbuckets
comb_ina_melt$Parent<-as.character("No")
comb_ina_melt$Parent[which(as.character(comb_ina_melt$Parent_Bucket) == as.character(comb_ina_melt$Sub_Bucket))]<-as.character("Yes")

#adding setting type to subbucket name
levels(comb_ina_melt$variable)<-c("IP","OP","IP_OP_COMB")
comb_ina_melt$Sub_Bucket<-paste(comb_ina_melt$Sub_Bucket,comb_ina_melt$variable,sep="_")

#removing unneeded "variable", rename "value", reorder columns
comb_ina_melt$variable<-NULL
colnames(comb_ina_melt)[which(colnames(comb_ina_melt)=="value")]<-"DORY_Settings"
comb_ina_melt<-comb_ina_melt[,c(1:2,20,3:19)]
comb_ina_melt<-comb_ina_melt[,c(1:6,20,7:19)]

write.table(comb_ina_melt, "transformed_output.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")

