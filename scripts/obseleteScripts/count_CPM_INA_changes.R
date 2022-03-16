#for (i in c("Behavioral_Health",
#"Cardiovascular",
#"Dermatology",
#"Digestive_Health",
#"Endocrinology",
#"ENT",
#"Gynecology",
#"Neurosciences",
#"Obstetrics",
#"Oncology_Hematology",
#"Opthamology",
#"Orthopedics",
#"Pulmonology",
#"Rheumatology",
#"Spine",
#"Urology")){


####uncomment above lines to run on a full monthly deliverable. below is used for testing opthamology subsample
i="Opthamology"
currdir="/vol/cs/clientprojects/PxDxStandardizationTesting/2016_05_26_INA_WKoldnew/changecount/may"
prevdir="/vol/cs/clientprojects/PxDxStandardizationTesting/2016_05_26_INA_WKoldnew/changecount/april"
####################

print(i)

#curr<-read.csv(file.path("/vol/cs/clientprojects/CPM/2016_04_15_CPM_INA_nonEMD",i,"Comb/links_fordelivery.txt"),sep="\t")
#prev<-read.csv(file.path("/vol/cs/clientprojects/CPM/2016_03_15_CPM_INA_nonEMD",i,"Comb/links_fordelivery.txt"),sep="\t")

#curr<-as.data.frame(scan(file=file.path("/vol/cs/clientprojects/CPM/2016_04_15_CPM_INA_EMD",i,"Comb/links_fordelivery.txt"),what=list("","","",""),skip=1),stringsAsFactors=F)
#prev<-as.data.frame(scan(file=file.path("/vol/cs/clientprojects/CPM/2016_03_15_PxDxs_INAs/2016_03_15_CPM_INA_EMD",i,"Comb/links_fordelivery.txt"),what=list("","","",""),skip=1),stringsAsFactors=F)

curr<-as.data.frame(scan(file=file.path(currdir,i,"Comb/links_fordelivery.txt"),what=list("","","",""),skip=1),stringsAsFactors=F)
prev<-as.data.frame(scan(file=file.path(prevdir,i,"Comb/links_fordelivery.txt"),what=list("","","",""),skip=1),stringsAsFactors=F)

names<-as.data.frame(scan(file="/vol/cs/CS_PayerProvider/Ryan/R/test_links.txt",what=list("","","",""),nlines=1),stringsAsFactors=F)

colnames(curr)<-names[1,]
colnames(prev)<-names[1,]

curr$id<-paste(curr$HMS_ID1,curr$HMS_ID2,sep="_")
prev$id<-paste(prev$HMS_ID1,prev$HMS_ID2,sep="_")
curr$old<-""
curr$old<-prev$SharedPatientCount[match(curr$id,prev$id)]
curr$diff<-as.numeric(curr$SharedPatientCount)-as.numeric(curr$old)
change<-curr[which(curr$diff != 0),]
print(nrow(change))

#}

#test2<-as.data.frame(scan(file="test_links.txt",what=list("","","",""),nlines=1),stringsAsFactors=F)

