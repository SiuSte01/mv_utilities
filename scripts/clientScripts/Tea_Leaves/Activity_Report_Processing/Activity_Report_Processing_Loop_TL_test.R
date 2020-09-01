#Set working directory
setwd("T:/Tea_Leaves/2018_04_27_TL_Activity_Report_testing/")

#Defining All Codes path and Previous run's path
#previous_path <- paste0("T:/Tea_Leaves/2018_04_30_PxDx_and_INA/")
AC_IP_path <- paste0("T:/PxDxStandardizationTesting/MonthlyAllCodes/Apr2018/CL_IP_E/QA/")
#AC_OP_path <- paste0("T:/PxDxStandardizationTesting/MonthlyAllCodes/Apr2018/CL_OPOA_E/QA/")

#Listing the Dx and Px Activity Reports directories needed
AR_dx_dirs <- c("ActivityReport_DxIPOnly_Emdeon","ActivityReport_DxOPOfficeASC_Emdeon")
AR_px_dirs <- c("ActivityReport_PxIPOnly_Emdeon","ActivityReport_PxOPOfficeASC_Emdeon")

#Creating Dx and Px ARs directories
folders <- c(AR_px_dirs, AR_dx_dirs)
for (i in 1:length(folders)) {dir.create(paste(".",folders[i], sep="/"))}

#Loop for copying AC individuals to Dx Activity Reports
for (dirs in AR_dx_dirs)
{ setwd(dirs)
  AR_ip_indivs <- paste0(AC_IP_path, pattern="individuals.tab", sep="")
  
}

  ------------------------------------------------------------------------------------------------------------------
#Loop for reading and transforming Dx Activity Reports
for (dirs in AR_dx_dirs)
{ setwd(dirs)
  
  AR_dx<- paste(".", "activity_breakout.txt",sep="/")
  act_report<-read.delim(AR_dx, header=T,sep="\t", quote="",comment.char="",colClasses=c("HMS_PIID"="character","DiagNoDecimal"="character", "Diag"="character","CodeType"="character","Count"="character","PctofClaims"="character","Description"="character"))
  act_report_no_desc<-act_report[,c(1:4,6)]
  code_desc_with_dupes<-act_report[,c(2,4,7)]
  
  unique_desc<-unique(code_desc_with_dupes)
  
  write.table(unique_desc,"code_description.txt",sep="\t",quote=FALSE,row.names=FALSE,na="")
  write.table(act_report_no_desc,"activityreport_nodesc.txt", sep="\t",quote=FALSE,row.names=FALSE,na="")
  
  file.copy("code_description.txt", ".")
  file.copy("activityreport_nodesc.txt", ".") 
  setwd("..")}

#########################################################################################################################

#Loop for reading and transforming Px Activity Reports
for (dirs in AR_px_dirs)
{ setwd(dirs)
  AR_px<- paste(".", "activity_breakout.txt",sep="/")
  act_report<-read.delim(AR_px, header=T,sep="\t", quote="",comment.char="",colClasses=c("HMS_PIID"="character","ProcNoDecimal"="character", "Proc"="character","CodeType"="character","Count"="character","PctofClaims"="character","Description"="character"))
  act_report_no_desc<-act_report[,c(1:4,6)]
  code_desc_with_dupes<-act_report[,c(2,4,7)]
  
  unique_desc<-unique(code_desc_with_dupes)
  
  write.table(unique_desc,"code_description.txt",sep="\t",quote=FALSE,row.names=FALSE,na="")
  write.table(act_report_no_desc,"activityreport_nodesc.txt", sep="\t",quote=FALSE,row.names=FALSE,na="")
  
  file.copy("code_description.txt", ".")
  file.copy("activityreport_nodesc.txt", ".") 
  setwd("..")}





