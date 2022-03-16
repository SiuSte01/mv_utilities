#code to pull payer mix aggregation from db and add piid using vintage
#parameters need to be specified in an input file
#vintage
#piidlist file if not entire dataset being delivered
#whether or not patient counts should be included

#update March 2017 to get profiles from profiledata

#read the parameters file
par<-read.table(file="inputs.txt",header=T,sep="\t",as.is=T,fill=T)

vint<-subset(par,Parameter=="Vintage")$Value
piidlistf<-subset(par,Parameter=="Piidlistfile")$Value
IncludeCounts<-subset(par,Parameter=="IncludeCounts")$Value

#check if ExcludeCash option is specified
#default is not to exclude
ExcludeCash="N"
idx<-grep("ExcludeCash",par$Parameter)
if(length(idx) > 0) {
 EC<-subset(par,Parameter=="ExcludeCash")$Value
 if(EC == "Y") {
  ExcludeCash="Y"
 }
}

#check if RoundToDigits is specified
idxr<-grep("RoundToDigits",par$Parameter)
roundtodigits<-1
if(length(idxr) > 0) {
 roundtodigits<-as.numeric(subset(par,Parameter=="RoundToDigits")$Value)
}

#check if IncludeNames is specified
idx<-grep("IncludeNames",par$Parameter)
includenames<-"N"
if(length(idx) > 0) {
 includenames<-subset(par,Parameter=="IncludeNames")$Value
}

#get npi to piid xwalk and piid fn, ln from profile data
library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", 
password = "claims_usr123", dbname = "pldwh2dbr")
myq1.1<-"select hms_piid, npi, first, last, practitioner_type from profiledata.practitioners "
myq1.2<-" where to_date('"
myq1.3<-"','YYYYMMDD') between begin_date and end_date "
myq1<-paste(myq1.1,myq1.2,vint,myq1.3,sep="") 
rs <- dbSendQuery(con, myq1)
profdata<-fetch(rs)

wantcols1<-c("HMS_PIID","NPI")
npi2piid<-profdata[,wantcols1]
npi2piid<-subset(npi2piid,!is.na(NPI))


#create dataset with piid names if requested
if(includenames == "Y") {
 wantcols2<-c("HMS_PIID","FIRST","LAST")
 piidnames<-subset(profdata,PRACTITIONER_TYPE %in% c('Physician','Optometrist',
  'Podiatrist','Physician Assistant','Advanced Practice Nurse'),
 select=wantcols2)
 colnames(piidnames)[2]<-"FIRST_NAME"
 colnames(piidnames)[3]<-"LAST_NAME"
}

#get the payer mix data
if(ExcludeCash == "N") {
 myq1<-paste("select physician_npi as NPI, hybrid_payer as PAYER,
 prct_pyr_ptnt_count as PTNT_COUNT, 
 round(prct_pyr_percentage,",roundtodigits,") as PERCENT
 from Pharma_claims.Phys_Hbrdpayer_percnt_mvw")
} else if(ExcludeCash == "Y") {
 myq1<-paste("select physician_npi as NPI, hybrid_payer as PAYER,
 prct_pyr_ptnt_count as PTNT_COUNT, 
  round(prct_pyr_prcnt_excshap,",roundtodigits,") as PERCENT
 from Pharma_claims.Phys_Hbrdpayer_percnt_mvw where prct_pyr_prcnt_excshap is not null")
}
rs <- dbSendQuery(con, myq1)
mixdata<- fetch(rs)

#get the date range
myq2<-"select * from PHARMA_CLAIMS.RX_CLAIM_AGGR_DATE_RANGE t"
rs2 <- dbSendQuery(con, myq2)
date.range<- fetch(rs2)
write.table(date.range,file="daterange.txt",row.names=F,col.names=T,
quote=F,sep="\t")

dbDisconnect(con)

#merge npi
comb<-merge(mixdata,npi2piid,by.x="NPI",by.y="NPI",all.x=T)

#subset to piidlist if not blank
if(piidlistf != "") {
 piidlist<-read.table(piidlistf,header=T,sep="\t",quote="",comment.char="",as.is=T,fill=T)
 comb<-subset(comb,HMS_PIID %in% unique(piidlist$HMS_PIID))
 cat("number of records for selected piids = ",nrow(comb),"\n")
}

colnames(comb)<-c("NPI","Payer","PatientCount",
"PercentOfPatientsPerPractitioner","HMS_PIID")

if(IncludeCounts == "N") {
 comb<-comb[,-3]
}

#remove NA values due to null NPIs or type 2 NPIs
comb<-subset(comb,HMS_PIID != 'NA')

#do MF name join if requested
if(includenames == "Y") {
 comb<-merge(comb,piidnames,by="HMS_PIID",all.x=T)
}

#output
write.table(comb,file="payermix.txt",col.names=T,row.names=F,
quote=F,sep="\t")


