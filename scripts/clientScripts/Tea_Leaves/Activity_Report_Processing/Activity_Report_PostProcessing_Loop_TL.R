#Set working directory
setwd("/vol/cs/clientprojects/Tea_Leaves/2018_10_31_PxDx_and_INA/")
#Listing the Dx and Px Activity Reports
AR_dx_dirs <- c("ActivityReport_DxIPOnly_Emdeon","ActivityReport_DxOPOfficeASC_Emdeon")
AR_px_dirs <- c("ActivityReport_PxIPOnly_Emdeon","ActivityReport_PxOPOfficeASC_Emdeon")

folders <- c(AR_px_dirs, AR_dx_dirs)

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
  setwd("..")
  rm(unique_desc)
  rm(act_report_no_desc)
  rm(act_report)
  rm(code_desc_with_dupes)
  gc()
}

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
  setwd("..")
  rm(act_report)
  rm(act_report_no_desc)
  rm(code_desc_with_dups)
  rm(unique_desc)
  gc()
}





