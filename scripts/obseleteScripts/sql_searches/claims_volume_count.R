
suppressMessages(library(ROracle))
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")


args = commandArgs(trailingOnly=TRUE)
#print(args)
fullcodes=args[1]

if(grepl(".tab",fullcodes)){
 fullcodes<-read.table(fullcodes,quote="",sep="",header=F,stringsAsFactors=F)
 fullcodes<-as.character(fullcodes)
 #print(fullcodes)
}else{
 fullcodes=args[1]
}

type=args[2]

ncodes<-length(unlist(strsplit(fullcodes,split=",")))
cutoff<-900
lowerlimit<-1
upperlimit<-cutoff
reps<-ncodes%/%cutoff+as.logical(ncodes/cutoff-ncodes%/%cutoff)
results<-as.data.frame(matrix(ncol=2,nrow=0))
colnames(results)<-c("SETTING","SUM(CLAIM_CNT)")

for (i in 1:reps){

 if (upperlimit > ncodes){upperlimit<-ncodes}
 #print(lowerlimit)
 #print(upperlimit)
 codes<-paste(unlist(strsplit(fullcodes,split=",")[[1]][lowerlimit:upperlimit]),collapse=",")
 #print(codes)

 if (type == "px" | type == "PX"){
 query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Px_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")
 }

 if (type == "dx" | type == "DX"){
 query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Dx_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")
 }

 if (type == "drg" | type == "DRG"){
 query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Drg_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")
 }

 rs <- try(dbSendQuery(con, query))

 if (! inherits(rs, "try-error")){
  claims <- fetch(rs)
  results<-aggregate(.~SETTING,rbind(claims,results),sum)
 }else{
  print(paste("Error accessing oracle. Query:",query))
 }

 lowerlimit<-lowerlimit+cutoff
 upperlimit<-upperlimit+cutoff

}

print(results)

#query<-"SELECT a.Setting, a.addnl_procedure_code, SUM(Claim_Cnt)
#  FROM Claims_Aggr.Claims_Smry_Dx_Mvw a
#WHERE a.addnl_diagnosis_code in ('8100','8104','8105','8106','8460','8463','8468')
#group by a.setting, a.addnl_diagnosis_code"
#rs <- dbSendQuery(con, query)
#dx_claims <- fetch(rs)



