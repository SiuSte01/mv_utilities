#Rscript for dealing with VGM codes as well as practice getting icd code data in r

codes<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/vgmA.txt",header=F,stringsAsFactors=F)

ranges<-codes[grep("-",codes$V1),]
not_ranges<-codes[grep("-",codes$V1,invert=TRUE),]

ranges<-strsplit(ranges,split=" - ")
ranges<-do.call(rbind,ranges)

#build crosswalk from number to decimal.
firstdec<-c("0","1","2","3","4","5","6","7","8","9")
seconddec<-c("","0","1","2","3","4","5","6","7","8","9")
fulldec<-list()

for (i in firstdec){
	for (j in seconddec){
		value<-paste(i,j,sep="")
		fulldec<-c(fulldec,value)
	}
}

guide<-data.frame("dec"=unlist(fulldec),"num"=c(seq(1:length(fulldec))),stringsAsFactors=F)

alltosearch<-list()

#build list of values
for (i in 1:nrow(ranges)){
	#get number before decimal, start of range, end of range
	first<-strsplit(ranges[i,1],split="\\.")[[1]][1]
	fdec<-strsplit(ranges[i,1],split="\\.")[[1]][2]
	ldec<-strsplit(ranges[i,2],split="\\.")[[1]][2]

	start<-guide$num[which(guide$dec==fdec)]
	end<-guide$num[which(guide$dec==ldec)]

	print(c(first,fdec,ldec,start,end))

	for (j in start:end){
		alltosearch<-c(alltosearch,paste(first,guide$dec[which(guide$num==j)],sep="."))
	}
}

#add back in those values that weren't ranges
alltosearch<-c(alltosearch,not_ranges)

#build query

query<-paste("select * from wh_stage.ICD9_ICD10_DIAG_BT where SOURCE_CODE IN ('",paste(alltosearch,collapse="','"),"')",sep="")

#search oracle

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", 
password = "claims_usr123", dbname = "pldwh2dbr")

#> query<-"select * from wh_stage.ICD9_ICD10_DIAG_BT where SOURCE_CODE = '718.46'"

rs <- dbSendQuery(con, query)
oracle_data <- fetch(rs)

#get codes
actual_codes<-unique(oracle_data$SOURCE_CODE)

actual_codes<-sort(actual_codes)

write.table(actual_codes,"output_codes.txt",row.names=F,col.names=FALSE,quote=F,sep=",")


#################################
#
#sort ICD10 into Dx and Px
#
#################################

ICD10codes<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/vgmICD10.txt",header=F,stringsAsFactors=F)

#query the diagnosis table to get all codes that are dx
query<-paste("select * from wh_stage.ICD10_ICD9_DIAG_BT where SOURCE_CODE IN ('",paste(ICD10codes[,1],collapse="','"),"')",sep="")

rs <- dbSendQuery(con, query);icd10_diag_oracle <- fetch(rs)
icd10_diag<-data.frame("code"=c(sort(unique(icd10_diag_oracle$SOURCE_CODE))),"type"="Dx")

#query the procedures table to get all codes that are px
query<-paste("select * from wh_stage.ICD10_ICD9_PROC_BT where SOURCE_CODE IN ('",paste(ICD10codes[,1],collapse="','"),"')",sep="")

rs <- dbSendQuery(con, query);icd10_proc_oracle <- fetch(rs)
icd10_proc<-data.frame("code"=c(sort(unique(icd10_proc_oracle$SOURCE_CODE))),"type"="Px")

#combine into one table 
icd10_all<-rbind(icd10_diag,icd10_proc)

write.table(icd10_all,"ICD10_codes.txt",row.names=F,col.names=FALSE,quote=F,sep=",")


dbDisconnect(con)


#########################
#
#organize data for running counts reports
#
#########################

#need 3 tables: all dx - code" "scheme;all px - code" "scheme;all DME code" "scheme

HCPCSproccodes<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/vgmpxcodes.txt",header=F,stringsAsFactors=F,colClasses="character")

DMEcodes<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/vgmproductcodes.txt",header=F,stringsAsFactors=F)

dx_icd9<-data.frame("code"=c(actual_codes),"scheme"="ICD9",stringsAsFactors=F)
dx_icd10<-data.frame("code"=c(as.character(icd10_diag$code)),"scheme"="ICD10",stringsAsFactors=F)
dx<-rbind(dx_icd9,dx_icd10)

px_icd10<-data.frame("code"=c(as.character(icd10_proc$code)),"scheme"="ICD10",stringsAsFactors=F)
px_hcpcs<-data.frame("code"=c(as.character(HCPCSproccodes$V1)),"scheme"="HCPCS",stringsAsFactors=F)
px<-rbind(px_icd10,px_hcpcs)

DME<-data.frame("code"=c(as.character(DMEcodes$V1)),"scheme"="HCPCS",stringsAsFactors=F)

#write out data
write.table(dx,"dx.txt",row.names=F,col.names=FALSE,quote=F,sep=" ")
write.table(px,"px.txt",row.names=F,col.names=FALSE,quote=F,sep=" ")
write.table(DME,"dme.txt",row.names=F,col.names=FALSE,quote=F,sep=" ")


















