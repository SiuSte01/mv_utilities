
suppressMessages(library(ROracle))
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")


args = commandArgs(trailingOnly=TRUE)
print(args)


codes=args[1]
type=args[2]


if (type == "px"){
query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Px_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")
}

if (type == "dx"){
query<-paste("SELECT SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Dx_Mvw a WHERE a.code in (",codes,")",sep="")
}

if (type == "drg"){
query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Drg_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")
}

rs <- try(dbSendQuery(con, query))

if (! inherits(rs, "try-error")){
 claims <- fetch(rs)
 print(claims)
}else{
 print(paste("Error accessing oracle. Query:",query))
}

#query<-"SELECT a.Setting, a.addnl_procedure_code, SUM(Claim_Cnt)
#  FROM Claims_Aggr.Claims_Smry_Dx_Mvw a
#WHERE a.addnl_diagnosis_code in ('8100','8104','8105','8106','8460','8463','8468')
#group by a.setting, a.addnl_diagnosis_code"
#rs <- dbSendQuery(con, query)
#dx_claims <- fetch(rs)



