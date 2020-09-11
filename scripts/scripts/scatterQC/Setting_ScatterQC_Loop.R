olddir<-"/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes/Feb2018_TL/PT_HOA_E_exact"
newdir<-"/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes/Feb2018_TL/PT_HOA_E_exact_Peds"

#Find all projections files
setwd(olddir)
old_proj_files<-list.files(olddir,"projections.txt",full.names = T,recursive=T)

setwd(newdir)
new_proj_files<-list.files(newdir,"projections.txt",full.names = T,recursive=T)

#ASC projections compare
old_asc<-grep("asc_projections.txt",old_proj_files)
new_asc<-grep("asc_projections.txt",new_proj_files)

#If both directories contain ASC projections
if (length(old_asc)>0 & length(new_asc)>0){
  asc_scatter_folder<-paste0(newdir,"/Projections/ASC/Setting_Scatter")
  dir.create(asc_scatter_folder)
  file.copy(from=old_proj_files[old_asc],to=paste0(asc_scatter_folder,"/old_projections.txt"))
  file.copy(from=new_proj_files[new_asc],to=paste0(asc_scatter_folder,"/new_projections.txt"))
  setwd(asc_scatter_folder)
  sink("Summary_Rout.txt")
  source("/vol/datadev/Statistics/Emily/MiscScripts/OldvNew_Projections/setting_scatterQC.R")
  sink()
  }

#Office projections compare
old_office<-grep("office_projections.txt",old_proj_files)
new_office<-grep("office_projections.txt",new_proj_files)

if (length(old_office)>0 & length(new_office)>0){
  office_scatter_folder<-paste0(newdir,"/Projections/Office/Setting_Scatter")
  dir.create(office_scatter_folder)
  file.copy(from=old_proj_files[old_office],to=paste0(office_scatter_folder,"/old_projections.txt"))
  file.copy(from=new_proj_files[new_office],to=paste0(office_scatter_folder,"/new_projections.txt"))
  setwd(office_scatter_folder)
  sink("Summary_Rout.txt",append = T)
  source("/vol/datadev/Statistics/Emily/MiscScripts/OldvNew_Projections/setting_scatterQC.R")
  sink()
  }

#OP projections compare
old_op<-grep("/OP/hospital_projections.txt",old_proj_files)
new_op<-grep("/OP/hospital_projections.txt",new_proj_files)

if (length(old_op)>0 & length(new_op)>0){
  op_scatter_folder<-paste0(newdir,"/Projections/Hospital/OP/Setting_Scatter")
  dir.create(op_scatter_folder)
  file.copy(from=old_proj_files[old_op],to=paste0(op_scatter_folder,"/old_projections.txt"))
  file.copy(from=new_proj_files[new_op],to=paste0(op_scatter_folder,"/new_projections.txt"))
  setwd(op_scatter_folder)
  sink("Summary_Rout.txt",append = T)
  source("/vol/datadev/Statistics/Emily/MiscScripts/OldvNew_Projections/setting_scatterQC.R")
  sink()
  }


#IP projections compare
old_ip<-grep("/IP/hospital_projections.txt",old_proj_files)
new_ip<-grep("/IP/hospital_projections.txt",new_proj_files)

if (length(old_ip)>0 & length(new_ip)>0){
  ip_scatter_folder<-paste0(newdir,"/Projections/Hospital/IP/Setting_Scatter")
  dir.create(ip_scatter_folder)
  file.copy(from=old_proj_files[old_ip],to=paste0(ip_scatter_folder,"/old_projections.txt"))
  file.copy(from=new_proj_files[new_ip],to=paste0(ip_scatter_folder,"/new_projections.txt"))
  setwd(ip_scatter_folder)
  sink("Summary_Rout.txt",append = T)
  source("/vol/datadev/Statistics/Emily/MiscScripts/OldvNew_Projections/setting_scatterQC.R")
  sink()
  }

#Combined hospital projections compare
old_hosp<-grep("/Hospital/hospital_projections.txt",old_proj_files)
new_hosp<-grep("/Hospital/hospital_projections.txt",new_proj_files)

if (length(old_hosp)>0 & length(new_hosp)>0){
  hosp_scatter_folder<-paste0(newdir,"/Projections/Hospital/Setting_Scatter")
  dir.create(hosp_scatter_folder)
  file.copy(from=old_proj_files[old_hosp],to=paste0(hosp_scatter_folder,"/old_projections.txt"))
  file.copy(from=new_proj_files[new_hosp],to=paste0(hosp_scatter_folder,"/new_projections.txt"))
  setwd(hosp_scatter_folder)
  sink("Summary_Rout.txt",append = T)
  source("/vol/datadev/Statistics/Emily/MiscScripts/OldvNew_Projections/setting_scatterQC.R")
  sink()
  }
