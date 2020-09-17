#read in current bucket definitions. These were provided by Sankar
bucketdir<-"/vol/cs/clientprojects/CPM/Documentation/CPMICD-10Mappings/Mapping_extracted_from_db"
cpt<-read.table(file.path(bucketdir,"hg_cpt_map.tab"),colClasses="character",sep="\t",quote="",header=F,as.is=T,comment.char="")
cpt$V1<-gsub("\\.","",cpt$V1)

dx<-read.table(file.path(bucketdir,"hg_dx_map.tab"),colClasses="character",sep="\t",quote="",header=F,as.is=T,comment.char="")
dx$V1<-gsub("\\.","",dx$V1)

px<-read.table(file.path(bucketdir,"hg_px_map.tab"),colClasses="character",sep="\t",quote="",header=F,as.is=T,comment.char="")
px$V1<-gsub("\\.","",px$V1)

drg<-read.table(file.path(bucketdir,"hg_msdrg_map.tab"),colClasses="character",sep="\t",quote="",header=F,as.is=T,comment.char="")
drg$V1<-gsub("\\.","",drg$V1)

#read in lists of all codes in our database. These lists are maintained by Sudheer.
codelist<-read.table("/vol/cs/clientprojects/CPM/2016_06_17_Code_check/complete_list.txt",colClasses="character",sep="\t",quote="",header=T,as.is=T,comment.char="")


codelist[,c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')] = NA

codelist[which(codelist$Type=="dx" & codelist$Scheme == "icd9" & codelist$Code %in% dx$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-dx[which(dx$V2 == 'ICD9'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="dx" & codelist$Schem == "icd9" & codelist$Code %in% dx$V1)],dx$V1[which(dx$V2 == 'ICD9')]),]

codelist[which(codelist$Type=="dx" & codelist$Scheme == "icd10" & codelist$Code %in% dx$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-dx[which(dx$V2 == 'ICD10'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="dx" & codelist$Schem == "icd10" & codelist$Code %in% dx$V1)],dx$V1[which(dx$V2 == 'ICD10')]),]

codelist[which(codelist$Type=="px" & codelist$Scheme == "icd9" & codelist$Code %in% px$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-px[which(px$V2 == 'ICD9'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="px" & codelist$Schem == "icd9" & codelist$Code %in% px$V1)],px$V1[which(px$V2 == 'ICD9')]),]

codelist[which(codelist$Type=="px" & codelist$Scheme == "icd10" & codelist$Code %in% px$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-px[which(px$V2 == 'ICD10'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="px" & codelist$Schem == "icd10" & codelist$Code %in% px$V1)],px$V1[which(px$V2 == 'ICD10')]),]

codelist[which(codelist$Type=="px" & codelist$Scheme == "hcpcs" & codelist$Code %in% cpt$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-cpt[which(cpt$V2 == 'HCPCS'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="px" & codelist$Schem == "hcpcs" & codelist$Code %in% cpt$V1)],cpt$V1[which(cpt$V2 == 'HCPCS')]),]

codelist[which(codelist$Type=="drg" & codelist$Scheme == "ms" & codelist$Code %in% drg$V1),c('PF_SERVICE_CATEGORY_CODE','CTGRY_DESCRIPTION','PF_SERVICE_CATEGORY_SUB_CODE','SUBCTGRY_DESCRIPTION')]<-drg[which(drg$V2 == 'MS-DRG'),c('V3','V4','V5','V6')][match(codelist$Code[which(codelist$Type=="drg" & codelist$Schem == "ms" & codelist$Code %in% drg$V1)],drg$V1[which(drg$V2 == 'MS-DRG')]),]

found<-codelist[which(! is.na(codelist$PF_SERVICE_CATEGORY_CODE)),]
extras<-rbind(dx[which(! dx$V1 %in% found$Code),],px[which(! px$V1 %in% found$Code),],cpt[which(! cpt$V1 %in% found$Code),],drg[which(! drg$V1 %in% found$Code),])


#decision was made not to attach codes we do not see in our data. vast majority are ICD10 header codes
extras$Scheme<-"icd10"
extras$Scheme[which(extras$V2=="ICD9")]<-"icd9"
newlines<-data.frame("Code"=extras$V1,"Description"="","Type"="","Scheme"=extras$Scheme,"PF_SERVICE_CATEGORY_CODE"=extras$V4,"CTGRY_DESCRIPTION"=extras$V5,"PF_SERVICE_CATEGORY_SUB_CODE"=extras$V6,"SUBCTGRY_DESCRIPTION"=extras$V7,stringsAsFactors=F)

###write out final codelist
write.table(codelist,"/vol/cs/clientprojects/CPM/2016_06_17_Code_check/merged_complete_codelist.tab",sep="\t",quote=F,row.names=F)





