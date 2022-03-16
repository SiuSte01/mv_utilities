### NOTE: There is overlap between px and dx codes. Best thing to do is look at them separately

#file<-read.csv("/vol/cs/clientprojects/Mount_Carmel/2016_05_19_Mammography/code_xwalk/codes.tab",header=F)
#file<-read.csv("/HDS/cs/clientprojects/K2M/2016_10_19_Fusion_MV/codelist.txt",header=F)
#file<-read.csv("/vol/cs/CS_PayerProvider/Ryan/testcodes.txt",header=F)
source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

args = commandArgs(trailingOnly=TRUE)
file<-read.hms(args[1],header=T)

#str(file)

#colnames(file)<-"code"
file$CODE<-gsub(pattern="\\.",replace="",file$CODE)
library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr",
password = "claims_usr123", dbname = "pldwh2dbr")

query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'HCPCS'"
rs <- dbSendQuery(con, query)
hcpcs_px <- fetch(rs)

query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'ICD9'"
rs <- dbSendQuery(con, query)
icd9_px <- fetch(rs)

query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'ICD10'"
rs <- dbSendQuery(con, query)
icd10_px <- fetch(rs)


query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Dx_Mvw WHERE Code_Scheme = 'ICD9'"
rs <- dbSendQuery(con, query)
icd9_dx <- fetch(rs)

query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Dx_Mvw WHERE Code_Scheme = 'ICD10'"
rs <- dbSendQuery(con, query)
icd10_dx <- fetch(rs)

query<-"SELECT * FROM CLAIMSWH.DRGS"
rs <- dbSendQuery(con, query)
drg <- fetch(rs)
drg$ADDNL_PROCEDURE_CODE<-drg$DRG_CODE

file[,c("hcpcs_px","icd9_px","icd10_px","icd9_dx","icd10_dx","drg")]<-0

for (i in c("hcpcs_px","icd9_px","icd10_px","icd9_dx","icd10_dx","drg")){
 temp<-get(i)
 file[[i]][which(file$CODE %in% temp$ADDNL_PROCEDURE_CODE)]<-1
 file[[i]][which(file$CODE %in% temp$CODE)]<-1

}

file$not_clasified<-0
file$not_clasified[which(apply(file[,c("hcpcs_px","icd9_px","icd10_px","icd9_dx","icd10_dx","drg")],1,sum) != 1)]<-1

write.hms(file,"classify_codes_out.txt")

#master_list<-data.frame("code"="","scheme"="","type"="")
#for (i in c("hcpcs_px","icd9_px","icd10_px","icd9_dx","icd10_dx")){
# temp<-get(i)
# temp<-temp[, c(grep("ADDNL",colnames(temp)),8,9)]
# colnames(temp)<-c("code","scheme","type")
# master_list<-rbind(master_list,temp)
#}


