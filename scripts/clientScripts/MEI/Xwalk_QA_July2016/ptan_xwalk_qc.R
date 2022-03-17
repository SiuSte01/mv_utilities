###R script for compare PTAN crosswalk
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
con <- dbConnect(drv, username = "hms_pe", password = "hms_pe123", dbname = "pldeldb")



### change 1 of 2 - update new and old XWALK table names here
new.name<- "TST_PE_NPI_ORG_20150514_IDENTI"
old.name<- "PE_NPI_ORG_20140912_IDENTIFIER"


### change 2 of 2 - update vintage table name here to get NPI to POID xwalk
vint.poids <- "DDB_20150415.M_ORG_NPI"

### pull data
myq.new<-"select type,identifier,npi from "
myq.old<-"select type,identifier,npi from "
myq.vint1<-"select hms_poid,org_npi,rank from "


myq.new<-paste(myq.new,new.name,sep="")
myq.old<-paste(myq.old,old.name,sep="") 
myq.vint<-paste(myq.vint1,vint.poids,sep="") 
 
rs1 <- dbSendQuery(con, myq.new)
rs2 <- dbSendQuery(con, myq.old)
rs3 <- dbSendQuery(con, myq.vint)
new.xwalk <- fetch(rs1)
old.xwalk <- fetch(rs2)
vint.xwalk <- fetch(rs3)



dbDisconnect(con)

###subset for types 4 and 7 and count/compare
new.xwalk2 <- new.xwalk[which(new.xwalk$TYPE=='04' | new.xwalk$TYPE== '07'),]
old.xwalk2 <- old.xwalk[which(old.xwalk$TYPE=='04' | old.xwalk$TYPE== '07'),]


new.rows<-nrow(new.xwalk2)
print(new.rows)

old.rows<-nrow(old.xwalk2)
print(old.rows)

###record count increase
percent.increase <- (((new.rows-old.rows)/old.rows)*100)

print(percent.increase)


### merge xwalk files with vintage POIDs where identifyer is not null

old.xwalk2<- old.xwalk2[which(old.xwalk2$IDENTIFIER != 'NA'),]
new.xwalk2<- new.xwalk2[which(new.xwalk2$IDENTIFIER != 'NA'),]

comb.old <- merge(old.xwalk2,vint.xwalk,by.x="NPI",by.y="ORG_NPI",all.x=T)
comb.new <- merge(new.xwalk2,vint.xwalk,by.x="NPI",by.y="ORG_NPI",all.x=T)

###counts with a POID match
poid.old<-comb.old[which(comb.old$HMS_POID != 'NA'),]
count.old<-nrow(poid.old)
percent.old<-count.old/old.rows*100
## percent of old xwalk with matching POIDs
print(percent.old)


poid.new<- comb.new[which(comb.new$HMS_POID != 'NA'),]
count.new<-nrow(poid.new)
percent.new<-count.new/new.rows*100
## percent of new xwalk with matching POIDs
print(percent.new)



### compare files for matches on NPI/POID
# create ID-type concatenation
old.cat<-paste(comb.old$TYPE,comb.old$IDENTIFIER,sep="")
new.cat<-paste(comb.new$TYPE,comb.new$IDENTIFIER,sep="")

comb.old2<-cbind(comb.old,old.cat)
comb.new2<-cbind(comb.new,new.cat)

comb.old<-comb.old2[,c(1,4,6)]
comb.new <- comb.new2[,c(1,4,6)]

colnames(comb.old)[3]<-"TYPE_ID"
colnames(comb.new)[3]<-"TYPE_ID"



comb<-merge(comb.old,comb.new,by="TYPE_ID",all=T)
count.comb<-nrow(comb)
print(count.comb)

### % match on NPI/POID - % non match
same.id<-comb[which(comb$NPI.x==comb$NPI.y & comb$HMS_POID.x==comb$HMS_POID.y),]
count.match<-nrow(same.id)
percent.match<-(count.match/count.comb)*100
### % match on both NPI and POID
print(percent.match)

same.id.or<-comb[which(comb$NPI.x==comb$NPI.y | comb$HMS_POID.x==comb$HMS_POID.y),]
count.or<-nrow(same.id.or)
percent.or<-(count.or/count.comb)*100
### % match on either NPI OR POID
print(percent.or)

bad.id<-comb[which(comb$NPI.x!=comb$NPI.y | comb$HMS_POID.x!=comb$HMS_POID.y),]
count.bad <- nrow(bad.id)
percent.bad <- (count.bad/count.comb)*100
### % with either mismatch on NPI or POID
print(percent.bad)

### sample of bad records
head(bad.id)
tail(bad.id)

### unique list of TYPE_ID concatenated values for bad records - write to file
bad.vals<-table(bad.id$TYPE_ID)


write.table(bad.vals,file="mismatch_vals_badID.txt",col.names=T,row.names=F,quote=F,sep="\t")

