##This is designed to take a list of codes from dory codeGroupFileTypeDescriptions.tab, query the database for codes and schemes, and output a table that can be used for delivery docs.


args = commandArgs(trailingOnly=TRUE)

if (length(args) < 1) {
  stop("Required args: infile\nexample: /vol/cs/CS_PayerProvider/Ryan/R/make_appendix_A_from_code_list.R '/vol/cs/clientprojects/Medtronic_MarketView_ELA/2016_03_22_Mastectomy_Ortho_rerun/codeGroupFileTypeDescriptions.tab'", call.=FALSE)
}

infile=args[1]
codes<-read.table(infile,header=T,stringsAsFactors=F,colClasses="character")
codes$CODE<-gsub("\\.","",codes$CODE)
codes$Description<-""
codes$Out_code<-""

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr",
password = "claims_usr123", dbname = "pldwh2dbr")

if ("DX" %in% codes$CODE_GROUP_TYPE){
 codelist_dx<-paste("'",codes$CODE[which(codes$CODE_GROUP_TYPE=="DX")],"'",collapse=",",sep="")
 #query<-paste("SELECT * FROM CLAIMSWH.DIAGNOSIS WHERE ADDNL_DIAGNOSIS_CODE IN (",codelist_dx,")")
 query<-paste("SELECT * FROM CLAIMSWH.DIAGNOSIS")
 dx_results<- fetch(dbSendQuery(con, query))
 dx_results<-dx_results[which(dx_results$DESCRIPTION != ""),]
 codes$Description[which(codes$CODE_GROUP_TYPE=="DX")]<-dx_results$DESCRIPTION[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="DX")],dx_results$ADDNL_DIAGNOSIS_CODE)]
 codes$Out_code[which(codes$CODE_GROUP_TYPE=="DX")]<-dx_results$DIAGNOSIS_CODE[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="DX")],dx_results$ADDNL_DIAGNOSIS_CODE)]
}

if ("PX" %in% codes$CODE_GROUP_TYPE){
 codelist_px<-paste("'",codes$CODE[which(codes$CODE_GROUP_TYPE=="PX")],"'",collapse=",",sep="")
 #query<-paste("SELECT * FROM CLAIMSWH.PROCEDURES WHERE ADDNL_PROCEDURE_CODE IN (",codelist_px,")")
 query<-paste("SELECT * FROM CLAIMSWH.PROCEDURES")
 px_results<- fetch(dbSendQuery(con, query))
 px_results<-px_results[which(px_results$DESCRIPTION != ""),]
 codes$Description[which(codes$CODE_GROUP_TYPE=="PX")]<-px_results$DESCRIPTION[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="PX")],px_results$ADDNL_PROCEDURE_CODE)]
 codes$Out_code[which(codes$CODE_GROUP_TYPE=="PX")]<-px_results$PROCEDURE_CODE[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="PX")],px_results$ADDNL_PROCEDURE_CODE)]
}

if ("DRG" %in% codes$CODE_GROUP_TYPE){
 codelist_drg<-paste("'",codes$CODE[which(codes$CODE_GROUP_TYPE=="DRG")],"'",collapse=",",sep="")
 #query<-paste("SELECT * FROM CLAIMSWH.DRGS WHERE DRG_CODE IN (",codelist_drg,")")
 query<-paste("SELECT * FROM CLAIMSWH.DRGS")
 drg_results<- fetch(dbSendQuery(con, query))
 drg_results<-drg_results[which(drg_results$DESCRIPTION != ""),]
 codes$Description[which(codes$CODE_GROUP_TYPE=="DRG")]<-drg_results$DESCRIPTION[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="DRG")],drg_results$DRG_CODE)]
 codes$Out_code[which(codes$CODE_GROUP_TYPE=="DRG")]<-drg_results$DRG_CODE[match(codes$CODE[which(codes$CODE_GROUP_TYPE=="DRG")],drg_results$DRG_CODE)]
}

output<-codes[,c("CODE_GROUP_NAME","Out_code","CODE_SCHEME","CODE_GROUP_TYPE","Description")]
colnames(output)<-c("Bucket","Code","Scheme","Type","Description")

write.table(output,file.path(dirname(infile),"appendixA.tab"),sep="\t",quote=F,row.names=F)

##old code from a different method

#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'HCPCS'"
#rs <- dbSendQuery(con, query)
#hcpcs_px <- fetch(rs)
#
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'ICD9'"
#rs <- dbSendQuery(con, query)
#icd9_px <- fetch(rs)
#
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw WHERE Code_Scheme = 'ICD10'"
#rs <- dbSendQuery(con, query)
#icd10_px <- fetch(rs)
#
#
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Dx_Mvw WHERE Code_Scheme = 'ICD9'"
#rs <- dbSendQuery(con, query)
#icd9_dx <- fetch(rs)
#
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Dx_Mvw WHERE Code_Scheme = 'ICD10'"
#rs <- dbSendQuery(con, query)
#icd10_dx <- fetch(rs)
#
#
#
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Dx_Mvw"
#rs <- dbSendQuery(con, query)
#dx <- fetch(rs)
#query<-"SELECT * FROM Claims_Aggr.Claims_Smry_Px_Mvw"
#rs <- dbSendQuery(con, query)
#px <- fetch(rs)
#
#codes$DESCRIPTION<-""


