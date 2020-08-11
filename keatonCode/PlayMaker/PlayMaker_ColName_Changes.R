#Set directories
hchb_directory<-"/vol/cs/clientprojects/Homecare_Homebase/2018-10-31_Readmit/milestones"
playmaker_directory<-getwd()

#Copy tab files from Homecare Homebase milestones folder to current directory
files_to_copy<-list.files(hchb_directory,".tab",full.names=T)
file.copy(files_to_copy,playmaker_directory)

#Read in tables that need changes
hosp_irf <- read.table("HOSPITAL_IRF.tab",header=T, sep="\t", quote="",comment.char="", colClasses="character",as.is=T, na.strings="")
hosp_hha <- read.table("HOSPITAL_HHA.tab",header=T, sep="\t", quote="",comment.char="", colClasses="character",as.is=T, na.strings="")
hosp_ltac <- read.table("HOSPITAL_LTAC.tab",header=T, sep="\t", quote="",comment.char="", colClasses="character",as.is=T, na.strings="")
hosp_snf <- read.table("HOSPITAL_SNF.tab",header=T, sep="\t", quote="",comment.char="", colClasses="character",as.is=T, na.strings="")
pt_quality_metrics <- read.table("Patient_Quality_Metrics.tab",header=T, sep="\t", quote="",comment.char="", colClasses="character",as.is=T, na.strings="N/A")


#Change column names to desired Playmaker column names
names(hosp_hha)<-gsub("^HHA_","AGENCY_",names(hosp_hha))
names(hosp_ltac)<-gsub("^LTAC_","AGENCY_",names(hosp_ltac))
names(hosp_snf)<-gsub("^SNF_","AGENCY_",names(hosp_snf))
names(hosp_irf)<-gsub("^IRF_","AGENCY_",names(hosp_irf))

#Write tables
write.table(hosp_irf, "./HOSPITAL_IRF.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")
write.table(hosp_hha, "./HOSPITAL_HHA.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")
write.table(hosp_ltac, "./HOSPITAL_LTAC.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")
write.table(hosp_snf, "./HOSPITAL_SNF.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")
write.table(pt_quality_metrics, "./Patient_Quality_Metrics.tab", sep="\t",quote=FALSE,row.names=FALSE,na="")



