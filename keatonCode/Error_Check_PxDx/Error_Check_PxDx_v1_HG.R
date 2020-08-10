#Directory used for testing
#setwd("T:/HealthGrades/2019_09_30_Refresh/2019_09_30_Client_Files/outDir/ncileGroups")

#Find all config directories within your folder for PxDx jobs only (ignore INA jobs)
matches.pxdx.files<-list.files(path=Sys.glob("group*/therapyLines/*/config"),pattern="jobVendorSettings.tab",recursive=F,full.names=T) 
matches.pxdx<-dirname(matches.pxdx.files)

#Run error check script for each PxDx job
for (i in 1:length(matches.pxdx)){
  setwd(matches.pxdx[i])
  print(getwd())
  error.check<-'/vol/cs/CS_PayerProvider/Ryan/utilities/qc_projections_v3.sh stderrout_proj > error_check.tab'
  system(error.check)
  setwd("../../../..")
}

#Print combined log for all jobs
matches.error.files<-list.files(path=Sys.glob("group*/therapyLines/*/config"),pattern="error_check.tab",recursive=F,full.names=T) 
matches.error<-dirname(matches.error.files)

sink("error_check_combined.txt")

for (i in 1:length(matches.error)){
  setwd(matches.error[i])
  print(getwd(),row.names=F)
  cat("\n")
  error_output <- read.delim("error_check.tab",header=F,as.is=T,row.names=NULL,stringsAsFactors = FALSE)
  colnames(error_output)<-NULL
  print.data.frame(error_output,row.names=F,right=F,quote=F)
  cat("\n")
  setwd("../../../..")
}

sink()