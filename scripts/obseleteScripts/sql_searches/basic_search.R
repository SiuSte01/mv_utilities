source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

suppressMessages(library(ROracle))
drv <- dbDriver("Oracle")

con <- dbConnect(drv, username = "hms_client_delivery", password = "hms_client_delivery123", dbname = "PLDELDB")
query="SELECT HMS_POID,ORG_NAME FROM ddb_20161214.M_ORGANIZATION where rank = 1"
addresses <- fetch(dbSendQuery(con, query))

con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")

args = commandArgs(trailingOnly=TRUE)

#query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Dx_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")

#for(i in args){

###find claims by piid, report counts by poid.
 query<-paste("select count (distinct prof.claim_id), xwalk.id_value,fxwalk.id_value from CLAIMSWH.PROF_CLAIMS prof
 inner join CLAIMSWH.PRACTITIONER_GROUP_MEMBERS pgm
 on  prof.practitioner_group_id = pgm.practitioner_group_id
 inner join CLAIMSWH.PRACTITIONER_ID_CROSSWALK xwalk
 on pgm.practitioner_id = xwalk.practitioner_id
 inner join CLAIMSWH.FACILITY_ID_CROSSWALK fxwalk
 on prof.facility_id = fxwalk.facility_id
 inner join CLAIMSWH.VENDORS vend
 on prof.vendor_id = vend.vendor_id
 where xwalk.id_value in ('",paste(args,collapse="','"),"') and xwalk.id_type = 'PIID' and fxwalk.id_type = 'POID'
 and prof.claim_through_date between vend.first_vend_date and vend.last_vend_date
 and prof.load_batch <= vend.last_vend_batch
 group by fxwalk.id_value, xwalk.id_value order by xwalk.id_value, count (distinct prof.claim_id) desc",sep="")

 query<-gsub("\n","",query)
 print(query) 
 sql_result <- fetch(dbSendQuery(con, query))
 colnames(sql_result)<-c("Count","HMS_PIID","HMS_POID")
 #print(i)
 sql_result$ORG_NAME=""
 sql_result$ORG_NAME<-addresses$ORG_NAME[match(sql_result$HMS_POID,addresses$HMS_POID)]
 sql_result$claim_type<-"1500"
 #print(sql_result)

 query2<-paste("select count (distinct inst.claim_id), xwalk.id_value,fxwalk.id_value from CLAIMSWH.INST_CLAIMS inst
 inner join CLAIMSWH.PRACTITIONER_GROUP_MEMBERS pgm
 on  inst.practitioner_group_id = pgm.practitioner_group_id
 inner join CLAIMSWH.PRACTITIONER_ID_CROSSWALK xwalk
 on pgm.practitioner_id = xwalk.practitioner_id
 inner join CLAIMSWH.FACILITY_ID_CROSSWALK fxwalk
 on inst.facility_id = fxwalk.facility_id
 inner join CLAIMSWH.VENDORS vend
 on inst.vendor_id = vend.vendor_id
 where xwalk.id_type = 'PIID' and xwalk.id_value in ('",paste(args,collapse="','"),"') and fxwalk.id_type = 'POID'
 and inst.claim_through_date between vend.first_vend_date and vend.last_vend_date
 and inst.load_batch <= vend.last_vend_batch 
 group by fxwalk.id_value, xwalk.id_value order by xwalk.id_value, count (distinct inst.claim_id) desc",sep="")

 query2<-gsub("\n","",query2)
 print(query2)
 sql_result2 <- fetch(dbSendQuery(con, query2))
 colnames(sql_result2)<-c("count","HMS_PIID","HMS_POID")
 #print(i)
 sql_result2$ORG_NAME=""
 sql_result2$ORG_NAME<-addresses$ORG_NAME[match(sql_result2$HMS_POID,addresses$HMS_POID)]
 sql_result2$claim_type<-"UB"
 #print(sql_result2)

 output<-rbind(sql_result,sql_result2)
 write.hms(output,paste("output",gsub(" ","_",Sys.time()),".txt",sep=""))
#}



