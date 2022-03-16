suppressMessages(library(ROracle))
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")

args = commandArgs(trailingOnly=TRUE)

#query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Dx_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")

#this is the slowest way to do this. should send one query, then sort

#for(i in args){

###find claims by piid, report counts by poid.
 query<-paste("select count (distinct prof.claim_id), xwalk.id_value,fxwalk.id_value,vend.vendor_name,pos.description
 from CLAIMSWH.PROF_CLAIMS prof
 inner join CLAIMSWH.PRACTITIONER_GROUP_MEMBERS pgm
 on  prof.practitioner_group_id = pgm.practitioner_group_id
 inner join CLAIMSWH.PRACTITIONER_ID_CROSSWALK xwalk
 on pgm.practitioner_id = xwalk.practitioner_id
 inner join CLAIMSWH.FACILITY_ID_CROSSWALK fxwalk
 on prof.facility_id = fxwalk.facility_id
 inner join CLAIMSWH.VENDORS vend
 on prof.vendor_id = vend.vendor_id
 inner join claimswh.plc_of_srvc_types pos
 on prof.claim_pos_id = pos.pos_type_id
 where xwalk.id_value in ('",paste(args,collapse="','"),"') and xwalk.id_type = 'PIID' and fxwalk.id_type = 'POID'
 and prof.claim_through_date between vend.first_vend_date and vend.last_vend_date
 and prof.load_batch <= vend.last_vend_batch
 group by fxwalk.id_value, xwalk.id_value, vend.vendor_name,pos.description order by xwalk.id_value, count (distinct prof.claim_id) desc",sep="")

 query<-gsub("\n","",query)
 print(query)
 sql_result <- fetch(dbSendQuery(con, query))
 #print(i)
 print(sql_result)

 query2<-paste("select count (distinct inst.claim_id), fxwalk.id_value,xwalk.id_value from CLAIMSWH.INST_CLAIMS inst
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
 sql_result <- fetch(dbSendQuery(con, query2))
 #print(i)
 print(sql_result)

#}

