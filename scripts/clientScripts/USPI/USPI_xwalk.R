#/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")
test<-read.csv("/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx/ICD9.tab",sep="\t",header=F,colClasses = "character")

query3<-paste("select * from wh_stage.ICD9_ICD10_PROC_BT where SOURCE_CODE IN ('",paste(as.character(unique(test$V2)),collapse="','"),"')",sep="")

rs <- dbSendQuery(con, query3)
oracle_data3 <- fetch(rs)

missing<-unique(test[,2])[which(! unique(test[,2]) %in% unique(oracle_data3$SOURCE_CODE))]



test2<-read.csv("/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx/HCPCS.tab",sep="\t",header=F,colClasses = "character")

query5<-"select SOURCE_CODE from wh_stage.ICD9_ICD10_PROC_BT"
rs <- dbSendQuery(con, query3)
oracle_ICD9 <- fetch(rs)

oracle_ICD9<-unique(oracle_ICD9$SOURCE_CODE)

test2$V2[which(test2$V2 %in% oracle_ICD9)]

#######this is the next step
xwalkout<-read.csv("/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx/Code_xwalk.txt",sep="\t",header=T,colClasses = "character")
ICD10<-xwalkout[,c(1,2,5,10)]
ICD10$SCHEME<-"ICD10"

ICD9<-xwalkout[which(!duplicated(xwalkout[,c(1,3)])),c(1,2,3,9)]
ICD9$SCHEME<-as.character("ICD9")

colnames(ICD9)[3:4]<-c("CODE","DESCRIPTION")
colnames(ICD10)[3:4]<-c("CODE","DESCRIPTION")

out<-rbind(ICD9,ICD10)

#######add in hcpcs
hcpcs<-read.csv("/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx/HCPCS.tab",sep="\t",header=T,colClasses = "character")

#query<-paste("select * from Claims_Aggr.Claims_Smry_Px_Mvw where CODE IN ('",paste(unique(hcpcs$CODE),collapse="','"),"')",sep="")
#rs <- dbSendQuery(con, query)
#oracle_hcpcs <- fetch(rs)

query<-"select * from Claims_Aggr.Claims_Smry_Px_Mvw where CODE_SCHEME = 'HCPCS'"
oracle_hcpcs <- fetch(dbSendQuery(con, query))
oracle_hcpcs<-oracle_hcpcs[which(!duplicated(oracle_hcpcs[,c(6,7)])),]

hcpcs$SCHEME<-"HCPCS"
hcpcs$DESCRIPTION<-oracle_hcpcs$DESCRIPTION[match(hcpcs$CODE,oracle_hcpcs$CODE)]

hcpcs<-hcpcs[,c("CODE_GROUP","TYPE","CODE","DESCRIPTION","SCHEME")]

colnames(hcpcs)<-colnames(out)

out<-rbind(out,hcpcs)

write.table(out,"/vol/cs/clientprojects/USPI/2015_10_21_ALLSURG_1_PxDx/All_9_and_10.txt",sep="\t",quote=F,row.names=F)




