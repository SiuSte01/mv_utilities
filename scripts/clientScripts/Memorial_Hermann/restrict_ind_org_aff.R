#this script is intended to be run AFTER the actual filter step, as a way to remove any indivs or orgs brought in during filtering which are not present in the actual network.
args = commandArgs(trailingOnly=TRUE)
source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

#affils_grp1_fordelivery.tab
#indivs_grp1_fordelivery.tab
#orgs_grp1_fordelivery.tab

#dir<-"/vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/Sep2016/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb/2016_12_16_GI_Colon_OP_Px"
#piidlist_path<-"/vol/cs/clientprojects/Memorial_Hermann/2016_12_08_MH_PxDxs/Gastro_PxDx/GI_Colon_OP_Px/piidlist.txt"

dir<-args[1]
piidlist_path<-args[2]


#file_list<-Sys.glob(paste(dir,"/*fordelivery.tab",sep=""))
file_list<-Sys.glob(paste(dir,"/*_filtered.tab",sep=""))
#network<-read.hms(file.path(dir,"network.txt"))
#allpiids<-unique(c(network$HMS_PIID1,network$HMS_PIID2))

piidlist<-read.hms(piidlist_path)
allpiids<-unique(piidlist$HMS_PIID)

allpoids<-""

for (i in file_list){
 if(file.exists(paste(i,".bak",sep=""))){
  print(paste("ERROR: ",i,".bak already exists. Skipping",sep=""))
  break
 }
 file_name<-basename(i)
 file.copy(i,paste(i,".bak",sep=""))
 file_type<-substring(file_name,1,3)
 if(file_type == "aff"){
  temp<-read.hms(i)
  temp<-temp[which(temp$HMS_PIID %in% allpiids),]
  allpoids<-unique(temp$HMS_POID)
  write.hms(temp,i)
 }else if(file_type == "ind"){
  temp<-read.hms(i)
  temp<-temp[which(temp$HMS_PIID %in% allpiids),]
  write.hms(temp,i)
 }else if(file_type == "org"){
  if(paste(allpoids,collapse="") == ""){
   print("ERROR: poids not identified correctly from affils")
   break
  }
  temp<-read.hms(i)
  temp<-temp[which(temp$HMS_POID %in% allpoids),]
  write.hms(temp,i)
 }

}


