#Directory used for testing
#setwd("T:/Tea_Leaves/2019_03_29_PxDx_and_INA/2019_03_29_PxDx_Emdeon")

#Find all config directories within your folder for PxDx jobs only (ignore INA jobs)
matches.pxdx.files<-list.files(path=Sys.glob("*/config"),pattern="jobVendorSettings.tab",recursive=F,full.names=T) 
matches.pxdx<-dirname(matches.pxdx.files)

#Run error check script for each PxDx job
for (i in 1:length(matches.pxdx)){
  setwd(matches.pxdx[i])
  print(getwd())
  error.check<-'/vol/cs/CS_PayerProvider/Ryan/utilities/qc_projections_v3.sh > error_check_test.tab'
  system(error.check)
  setwd("../..")
}

#Print combined log for all jobs
matches.error.files<-list.files(path=Sys.glob("*/config"),pattern="error_check_test.tab",recursive=F,full.names=T) 
matches.error<-dirname(matches.error.files)

sink("error_check_combined.txt")

for (i in 1:length(matches.error)){
  setwd(matches.error[i])
  print(getwd(),row.names=F)
  cat("\n")
  error_output <- read.delim("error_check_test.tab",header=F,as.is=T,row.names=NULL,stringsAsFactors = FALSE)
  colnames(error_output)<-NULL
  print.data.frame(error_output,row.names=F,right=F,quote=F)
  cat("\n")
  setwd("../..")
}

sink()
