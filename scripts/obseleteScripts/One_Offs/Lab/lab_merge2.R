clia<-read.table("clia_profiles.tab", sep="\t",as.is=T,quote="",comment.char="",header=T)
npi<-read.table("npi_profiles.tab", sep="\t",as.is=T,quote="",comment.char="",header=T)
claims<-read.table("lab_counts_20160720.txt", sep="\t",as.is=T,quote="",comment.char="",header=T)
head(claims)
head(clia)
head(npi)
colnames(clia)
colnames(NPI)
colnames(npi)
colnames(claims)
npi.sub<-npi[,c(5,31,32)]
colnames(npi.sub0
colnames(npi.sub)
npi.sub<-npi[,c(1,5,31,32)]
colnames(npi.sub)
clia.sub<-clia[,c(18,12,5,21)]
colnames(clia.sub)
merge.npi<-merge(claims,npi,by="NPI",all.x=T)
colnames(merge.npi)
merge.npi<-merge(claims,npi.sub,by="NPI",all.x=T)
colnames(merge.npi)
head(merge.npi)
merge.clia<-merge(merge.npi,clia.sub,by.x="CLIA", by.y="PRVDR_NUM",all.x=T)
head(merge.clia0
head(merge.clia)
tail(merge.clia)
str(merge.clia)
colnames(merge.clia)
colnames(merge.clia)[3]<-"NPI_CLM_CNT"
colnames(merge.clia)[4]<-"CLIA_CLM_CNT"
colnames(merge.clia)[5]<-"TOTAL_CLM_CNT"
colnames(merge.clia)[6]<-
colnames(merge.clia)[6]<-"NPI_FAC_NAME"
colnames(merge.clia)[9]<-"CLIA_FAC_NAME"
colnames(merge.clia)[7]<-"NPI_CITY"
colnames(merge.clia)[8]<-"NPI_STATE"
colnames(merge.clia)[11]<-"CLIA_STATE"
colnames(merge.clia)[10]<-"CLIA_CITY"
colnames(merge.clia)
dim(merge.clia)
dim(claims)
tail(merge.clia)
write.table(merge.clia, file="Lab_claims_with_raw_profiles.tab",col.names=T,row.names=F,
quote=F,sep="\t")
quit()
clia<-read.table("clia_profiles.tab", sep="\t",as.is=T,quote="",comment.char="",header=T)
npi<-read.table("npi_profiles.tab", sep="\t",as.is=T,quote="",comment.char="",header=T)
claims<-read.table("lab_counts_20160720.txt", sep="\t",as.is=T,quote="",comment.char="",header=T)
head(claims)
head(clia)
head(npi)
colnames(clia)
colnames(npi)
npi.sub<-npi[,c(5,29,30,31,32,33)]
clia.sub<-clia[,c(12,24,35,5,21,30)]
head(clia.sub)
head(npi.sub)
colnames(clia.sub)
merge.npi<-merge(claims,npi.sub,by="NPI",all.x=T)
colnames(claims)
colnames(npi.sub)
colnames(clia.sub)
clia.sub<-clia[,c(18,12,24,35,5,21,30)]
npi.sub<-npi[,c(1,5,29,30,31,32,33)]
head(clia.sub)
head(npi.sub)
merge.npi<-merge(claims,npi.sub,by="NPI",all.x=T)
head(merge.npi)
merge.clia<-merge(merge.npi,clia.sub,by.x="CLIA", by.y="PRVDR_NUM",all.x=T)
colnames(merge.clia)
colnames(merge.clia)[3]<-"NPI_CLM_CNT"
colnames(merge.clia)[4]<-"CLIA_CLM_CNT"
colnames(merge.clia)[5]<-"TOTAL_CLM_CNT"
colnames(merge.clia)[6]<-"NPI_FAC_NAME"
colnames(merge.clia)[7]<-"NPI_ADDR_1"
colnames(merge.clia)[8]<-"NPI_ADDR_2"
colnames(merge.clia)[9]<-"NPI_CIDY"
colnames(merge.clia)[9]<-"NPI_CITY"
colnames(merge.clia)[10]<-"NPI_STATE"
colnames(merge.clia)[11]<-"NPI_ZIP"
colnames(merge.clia)[12]<-"CLIA_FAC_NAME"
colnames(merge.clia)[13]<-"CLIA_ADDR_1"
colnames(merge.clia)[14]<-"CLIA_ADDR_2"
colnames(merge.clia)[15]<-"CLIA_CITY"
colnames(merge.clia)[16]<-"CLIA_STATE"
colnames(merge.clia)[17]<-"CLIA_ZIP"
colnames(merge.clia)
write.table(merge.clia, file="Lab_claims_with_raw_profiles.tab",col.names=T,row.names=F,
write.table(merge.clia, file="Lab_claims_with_raw_profiles2.tab",col.names=T,row.names=F,quote=F,sep="\t")
quit()
