
links <- read.table("/vol/cs/clientprojects/Sales_Support/Semi_Annual_Sales_Buckets/2018_04_20_Sample_Datasets/All_Codes_Directional_INA/PIIDTOPIID_All_Codes_Directional/Comb/links.txt",header=T,sep="\t",as.is=T,quote="\"",comment.char="")
network <- read.table ("/vol/cs/clientprojects/Sales_Support/Semi_Annual_Sales_Buckets/2018_04_20_Sample_Datasets/All_Codes_Directional_INA/PIIDTOPIID_All_Codes_Directional/Comb/2018_06_15_Baptist_SS/network_full.txt",header=T,sep="\t",as.is=T,quote="\"",comment.char="")

dim(links)
dim(network)

links$cat<-(paste(links$VAR1,links$COUNT,sep=""))
network$cat<-(paste(network$HMS_PIID1,":",network$HMS_PIID2,network$SHAREDPATIENTCOUNT,sep=""))

#subset to only records in links 
merged <- merge(links,network,by="cat")
dim(merged)

colnames(merged)
network_fixed <- merged[,c(5:57)]

write.table(network_fixed,file="network_full.txt",col.names=T,row.names=F,
quote=F,sep="\t")

