source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

file<-commandArgs(trailingOnly=TRUE)[1]
if(! file.exists(file)){stop("file not found")}

#testing#
#file<-"/vol/cs/clientprojects/Medtronic_MarketView_ELA/2016_04_12_Breast_INA/Breast_dx_to_px/Comb/national_filter/network.txt"

data<-read.hms(file)

if(! any(grepl('TERR',colnames(data)))){stop("no TERR columns found. Has this already been run?")}

if(! any(grepl('GRP1_VOLUME_TERR_RANK2',colnames(data)))){
 cat("no GRP1_VOLUME_TERR_RANK2 found. Running as dx -> px.\n")
 instructions<-data.frame("to_remove"=c("GRP1_VOLUME_NATL_RANK","NATL_NUM_CONN_GRP2_ENTITIES","GRP2_VOLUME_NATL_RANK","NATL_NUM_CONN_GRP1_ENTITIES","NATL_SOR_VALUE"),"to_rename"=c("GRP1_VOLUME_TERR_RANK","TERR_NUM_CONN_GRP2_ENTITIES","GRP2_VOLUME_TERR_RANK","TERR_NUM_CONN_GRP1_ENTITIES","TERR_SOR_VALUE"))

 #remove the GRP1_VOLUME_NATL_RANK field
 #rename the GRP1_VOLUME_TERR_RANK field to GRP1_VOLUME_NATL_RANK
 #remove the NATL_NUM_CONN_GRP2_ENTITIES field
 #rename the TERR_NUM_CONN_GRP2_ENTITIES field to NATL_NUM_CONN_GRP2_ENTITIES
 #remove the GRP2_VOLUME_NATL_RANK field
 #rename the GRP2_VOLUME_TERR_RANK field to GRP2_VOLUME_NATL_RANK
 #remove the NATL_NUM_CONN_GRP1_ENTITIES field
 #rename the TERR_NUM_CONN_GRP1_ENTITIES field to NATL_NUM_CONN_GRP1_ENTITIES
 #remove NATL_SOR_VALUE field
 #rename the Terr_SOW_Value field to NATL_SOR_VALUE

 data<-data[,which(! colnames(data) %in% instructions$to_remove)]
 colnames(data)[which(colnames(data) %in% instructions$to_rename)]<-as.character(instructions$to_remove)

 file.copy(file,paste(file,"_backup",sep=""))

 write.table(data,file,sep="\t",quote=F,row.names=F)
}else{
 cat("GRP1_VOLUME_TERR_RANK2 found. Running as dx -> dx.\n")
 instructions<-data.frame("to_remove"=c("GRP1_VOLUME_NATL_RANK1","NATL_NUM_CONN_ENTITIES1","GRP1_VOLUME_NATL_RANK2","NATL_NUM_CONN_ENTITIES2","NATL_SOR_VALUE"),"to_rename"=c("GRP1_VOLUME_TERR_RANK1","TERR_NUM_CONN_ENTITIES1","GRP1_VOLUME_TERR_RANK2","TERR_NUM_CONN_ENTITIES2","TERR_SOR_VALUE"))

 data<-data[,which(! colnames(data) %in% instructions$to_remove)]
 colnames(data)[which(colnames(data) %in% instructions$to_rename)]<-as.character(instructions$to_remove)

 file.copy(file,paste(file,"_original",sep=""))

 write.table(data,file,sep="\t",quote=F,row.names=F,na="")


}



