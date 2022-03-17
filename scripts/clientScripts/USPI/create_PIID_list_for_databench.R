INA<-read.csv("/vol/cs/clientprojects/USPI/2018_10_20_Refresh_USPI_Galerie/2018_10_20_INA_Refresh/ALL_SURGERY/Comb/Filter/allcodeslinks2.txt",sep="\t",stringsAsFactors=F)
pxdx<-read.csv("/vol/cs/clientprojects/USPI/2018_10_20_Refresh_USPI_Galerie/2018_10_20_PxDx_Refresh/ALL_SURGERY/milestones/HMS_Individuals.tab",sep="\t",stringsAsFactors=F)

outfile<-"/vol/cs/clientprojects/USPI/2018_10_20_Refresh_USPI_Galerie/2018_10_20_PxDx_Refresh/David_Inputs/PIID_list.txt"
inafile<-"/vol/cs/clientprojects/USPI/2018_10_20_Refresh_USPI_Galerie/2018_10_20_INA_Refresh/ALL_SURGERY/Comb/Filter/allcodeslinks2.txt"
pxdxfile<-"/vol/cs/clientprojects/USPI/2018_10_20_Refresh_USPI_Galerie/2018_10_20_PxDx_Refresh/ALL_SURGERY/milestones/HMS_Individuals.tab"

INA<-as.data.frame(scan(file=inafile,what=list("","","","",""),skip=1),stringsAsFactors=F)

names<-as.data.frame(scan(file=inafile,what=list("","","","",""),nlines=1),stringsAsFactors=F)
colnames(INA)<-c(names[1,])

pxdx<-read.csv(pxdxfile,sep="\t",stringsAsFactors=F)

INA_PIIDS1<-unique(INA$HMS_PIID1)
INA_PIIDS2<-unique(INA$HMS_PIID2)
INA_PIIDS<-c(INA_PIIDS1,INA_PIIDS2[which(! INA_PIIDS2 %in% INA_PIIDS1)])

PIID_LIST<-INA_PIIDS[which(! INA_PIIDS %in% pxdx$HMS_PIID)]

write.table(PIID_LIST,outfile,col.names=F,row.names=F,quote=F)






