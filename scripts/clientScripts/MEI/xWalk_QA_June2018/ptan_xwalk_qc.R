#### script for comparing PTAN crosswalk
#### 
####  To Run:
##### 1) copy script to your location
####  2) make 2 changes: update new/old xwalk table names and update vintage table for
####  	org npi xwalk
####  3)open plsas01 and run following command
####  R CMD BATCH --vanilla /vol/datadev/Statistics/Emily/MEI/ptan_xwalk_qc.R
	
##########################################################################################
## get xwalk data

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")


#get NPI xwalk
# CHANGE 1 of 2 - update vintage here
rs1<-"
select hms_poid, value, rank from profiledata.poid_identifiers_view
where id_type = 'NPI'
and vintage = to_date('2018-06-13','YYYY-MM-DD')
"

#get existing ptan xwalk
# will need to update query to account for start/end dates
rs2<-"select npi,identifier,state,issuer from wh_stage.nppes_org_id_crosswalk
where type in ('04','07')"


### get QA ptan xwalk
rs3<-"select npi,identifier,state,issuer from wh_stage.nppes_org_id_crosswalk_qa
where type in ('04','07')"

### get PTANS with MEI claims in last 12 months
# CHANGE 2 of 2 - update claim time period here - will move to Q3,Q4 2015 + Q1,Q2 2016 in June 2017
rs4<-"select t.supplier_ptan as IDENTIFIER, sum(t.units_allowed-t.units_denied) as COUNT from hcfa_saf.mei_dme_claims t
where t.claim_year = '2017'
and t.date_of_serv_quarter in ('Q1','Q2','Q3','Q4')
group by t.supplier_ptan"

#pull data

 
vint <- dbSendQuery(con, rs1)
old <- dbSendQuery(con, rs2)
new <- dbSendQuery(con, rs3)
claims <- dbSendQuery(con, rs4)
new.xwalk <- fetch(new)
old.xwalk <- fetch(old)
vint.xwalk <- fetch(vint)
mei.claims <- fetch(claims)



dbDisconnect(con)

#cleanup xwalks
colnames(vint.xwalk)[2]<-"NPI"

new.rows<-nrow(new.xwalk)
print(new.rows)

old.rows<-nrow(old.xwalk)
print(old.rows)

###record count increase
percent.increase <- (((new.rows-old.rows)/old.rows)*100)

print(percent.increase)


### clean up bad identifiers - dropping nulls, ones with <9 characters and ones with = signs

old.xwalk2<- old.xwalk[which(old.xwalk$IDENTIFIER != 'NA'),]
new.xwalk2<- new.xwalk[which(new.xwalk$IDENTIFIER != 'NA'),]

old.xwalk2<-old.xwalk2[which(nchar(old.xwalk2$IDENTIFIER)>8),]
new.xwalk2<-new.xwalk2[which(nchar(new.xwalk2$IDENTIFIER)>8),]

sub.old <-grep("=",old.xwalk2$IDENTIFIER)
sub.new <-grep("=",new.xwalk2$IDENTIFIER)

old.xwalk2<-old.xwalk2[-sub.old,]
new.xwalk2<-new.xwalk2[-sub.new,]
old.xwalk2<-unique(old.xwalk2)
new.xwalk2<-unique(new.xwalk2)

### merge in claim counts

old.xwalk3<-merge(old.xwalk2,mei.claims,by='IDENTIFIER',all.x=T)
new.xwalk3<-merge(new.xwalk2,mei.claims,by='IDENTIFIER',all.x=T)

### merge xwalk files with vintage POIDs

comb.old <- merge(old.xwalk3,vint.xwalk,by="NPI",all.x=T)
comb.new <- merge(new.xwalk3,vint.xwalk,by="NPI",all.x=T)

###counts with a POID match
old.rows<-nrow(comb.old)
poid.old<-comb.old[which(comb.old$HMS_POID != 'NA'),]
count.old<-nrow(poid.old)
percent.old<-count.old/old.rows*100
## percent of old xwalk with matching POIDs
print(percent.old)

new.rows<-nrow(comb.new)
poid.new<- comb.new[which(comb.new$HMS_POID != 'NA'),]
count.new<-nrow(poid.new)
percent.new<-count.new/new.rows*100
## percent of new xwalk with matching POIDs
print(percent.new)


### create new field that concatenates Identifier value (PTAN) with identifier type (04 or 07)
###droppint this step - don't need to worry about differences related to type 04/07

#old.cat<-paste(comb.old$TYPE,comb.old$IDENTIFIER,sep="")
#new.cat<-paste(comb.new$TYPE,comb.new$IDENTIFIER,sep="")

#comb.old2<-cbind(comb.old,old.cat)
#comb.new2<-cbind(comb.new,new.cat)


#want to keep POID, NPI,identifier (ptan) fields and COUNT

comb.old<-comb.old[,c(1,2,6,5)]
comb.new <- comb.new[,c(1,2,6,5)]

#colnames(comb.old)[4]<-"TYPE_ID"
#colnames(comb.new)[4]<-"TYPE_ID"


###create denomenator of total ID_TYPEs across old and new files
both <-rbind(comb.old,comb.new)
both <- unique(both)
count.total <-nrow(both)

### merge on type IDs
comb<-merge(comb.old,comb.new,by=c("IDENTIFIER"),all=T)

### recordcount/calc % match
count.comb<-nrow(comb)
match<-which(comb$NPI.x==comb$NPI.y & comb$HMS_POID.x ==comb$HMS_POID.y)
count.match<-length(match)
percent.match<-count.match/count.comb*100
print(percent.match)

### create dataset where records don't match on both NPI and POID
non.match <-comb[-match,]

### limit to non matching records with claims volume

non.match2<-non.match[which(non.match$COUNT.x !='NA'),]

###print non-matching results with MEI claims volume
write.table(non.match2,file="all_diff_matches.txt",col.names=T,row.names=F,quote=F,sep="\t")

drops<- non.match2[which(non.match2$COUNT.x >100 & is.na(non.match2$HMS_POID.y)),]

###print records with MEI record count volume > 100 where new xwalk contains no POID match
write.table(drops,file="drops_to_review.txt",col.names=T,row.names=F,quote=F,sep="\t")



