
#.libPaths("/home/rhopson/R/x86_64-redhat-linux-gnu-library/3.1")
suppressWarnings(library(sqldf))
options(gsubfn.engine = "R")

folders<-c("CKD3","CKD4","CKD5","ESRD")
#folders<-c("CKD3")
#folders<-c("CKD3","CKD5","ESRD") #for troubleshooting
month_path<-"2018_06_30_refresh/CKD_vascular_cardio_INA/"
month_path_pxdx<-"2018_06_30_refresh/CKD_vascular_cardio/"

for (i in folders){
 print(i)
 if(! file.exists(paste("/vol/cs/clientprojects/Fresenius/",month_path,i,"_DxCohort/Comb/Filter/network_restricted.txt",sep=""))){
  network_path<-paste("/vol/cs/clientprojects/Fresenius/",month_path,i,"_DxCohort/Comb/Filter/network.txt",sep="")
  indivs_path<-paste("/vol/cs/clientprojects/Fresenius/",month_path_pxdx,i,"/QA/individuals.tab",sep="")

  system(paste('sed -i s/"\'"/"~"/g',network_path))
 
  net<-file(network_path)
  ind<-file(indivs_path)
 
  network<-sqldf("select * from net", dbname = tempfile(), file.format = list(header = T, row.names = F,sep="\t"))
  indivs<-sqldf("select HMS_PIID from ind", dbname = tempfile(), file.format = list(header = T, row.names = F,sep="\t"))
 
  network_filtered<-network[which(network$HMS_PIID2 %in% indivs$HMS_PIID),]
  outpath<-paste("/vol/cs/clientprojects/Fresenius/",month_path,i,"_DxCohort/Comb/Filter/network_restricted.txt",sep="")
  write.table(network_filtered,paste("/vol/cs/clientprojects/Fresenius/",month_path,i,"_DxCohort/Comb/Filter/network_restricted.txt",sep=""),row.names=F,sep="\t",quote=F,na="")

  system(paste('sed -i s/"~"/"\'"/g',outpath))
  system(paste('sed -i s/"~"/"\'"/g',network_path))
 }else{
  print("already filtered")
 }
}







