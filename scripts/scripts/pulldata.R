#code to pull claim counts data 

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", 
password = "claims_usr123", dbname = "pldwh2dbr")
claims_data<-"select f.id_value, v.vendor_code, extract(year from to_date(i.claim_through_date,'YYYYMMDD')) as year ,
count(i.claim_id) from claimswh.inst_claims i
       inner join claimswh.vendors v
             on i.vendor_id = v.vendor_id
       inner join claimswh.facility_id_crosswalk f
             on f.facility_id = i.facility_id
where v.vendor_code like 'CMS%' 
and f.id_value in ('121302',
'490134',
'45069F',
'220174',
'190009',
'510053',
'670018',
'670002',
'340153',
'454112',
'440174',
'190175',
'050016',
'360195',
'250051',
'363032',
'330225',
'670029',
'220051',
'281317',
'450373',
'174010',
'391311',
'050435',
'361305',
'110183',
'450795',
'050385',
'330263',
'150154',
'440064',
'450591',
'013027',
'530010',
'100239',
'220067',
'341310',
'233025',
'040042',
'360116',
'510059',
'110203',
'050111',
'010025',
'450188',
'014009',
'111321',
'450270',
'244016',
'450296',
'430094',
'164004',
'260147',
'050545',
'124001',
'100076',
'110186',
'444019',
'510085',
'330213',
'451302',
'194076',
'450884',
'133025',
'181303',
'193089',
'330067',
'213300',
'220082',
'051993',
'150003',
'070015',
'264027',
'114015',
'271305',
'490135',
'044020')
and extract(year from to_date(i.claim_through_date,'YYYYMMDD')) > 2013
group by  f.id_value, v.vendor_code, extract(year from to_date(i.claim_through_date,'YYYYMMDD'))
"


rs <- dbSendQuery(con, claims_data)
claims_data2 <- fetch(rs)

dbDisconnect(con)

### ensure that the pull functioned properly and that the fields are pulled in correctly
names<-colnames(claims_data2)
print(names)


#output
write.table(claims_data2,file="pos_cms_clm_counts.txt",col.names=T,row.names=F,
quote=F,sep="\t")


