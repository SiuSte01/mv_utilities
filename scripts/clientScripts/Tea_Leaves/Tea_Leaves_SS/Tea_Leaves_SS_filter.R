###this is designed to filter tealeaves data for sales support based on a list of NPIs provided by client


args = commandArgs(trailingOnly=TRUE)

if (length(args) < 5) {
  stop("Required args: indir outdir npi_list filter_column all_codes\nexample: /vol/cs/CS_PayerProvider/Ryan/R/Tea_Leaves_SS_filter.R '/vol/cs/clientprojects/Tea_Leaves/2016_02_29_Tea_Leaves_Delivery/2016_02_29_Tea_Leaves_Emdeon_Delivery/Ortho_Px/milestones' '/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_03_25_Ortho_Baylor/delivery_test' '/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_03_25_Ortho_Baylor/Client_PIID_List/client_npis.txt' 2 0", call.=FALSE)
}

indir=args[1]
outdir=args[2]
npi_list=args[3]
filter_column=args[4]
all_codes=args[5]
#all_codes is now set by user rather than auto detected - 2/10/17 rdh

if(! file.exists(indir)){stop(print(paste(indir,"does not exist.")))}
if(! file.exists(outdir)){stop(print(paste(outdir,"does not exist.")))}

#all_codes<-0
#if(any(grepl("AllCodes",indir))){all_codes<-1}
#if(any(grepl("All_Codes",indir))){all_codes<-1}
#if(filter_column==1){all_codes<-1} ##added 9/1/16 at gd's request. TeaLeaves requested dx for the first time rather than px or allcodes - rdh

cat("\nRunning with args:\nindir:\t\t",indir,"\noutdir:\t\t",outdir,"\nnpi_list:\t",npi_list,"\nfilter_column:\t",filter_column,"\nall_codes:\t",all_codes,"\n\n")

####this will need to be set by the user, hardcoded for development
#indir<-"/vol/cs/clientprojects/Tea_Leaves/2016_02_29_Tea_Leaves_Delivery/2016_02_29_Tea_Leaves_Emdeon_Delivery/Ortho_Px/milestones"
#outdir<-"/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_03_25_Ortho_Baylor/delivery_test"
#npi_list<-"/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_03_25_Ortho_Baylor/Client_PIID_List/client_npis.txt"
#filter_column<-2

####read in data
npis<-read.csv(npi_list)
#if(all_codes==0){
 cat("Reading indivs\n")
 indivs<-read.csv(file.path(indir,"Splitter_Ind.tab"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 cat("Reading network\n")
 network<-read.csv(file.path(indir,"network.tab"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 cat("Reading network profiles\n")
 network_profiles<-read.csv(file.path(indir,"network_indiv_profiles.tab"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 cat("Reading pxdx\n")
 pxdx<-read.csv(file.path(indir,"PXDX.tab"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 cat("Reading org\n")
 org<-read.csv(file.path(indir,"Splitter_Org.tab"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
#}else{
 #cat("Reading indivs\n")
 #indivs<-read.csv(file.path(indir,"Splitter_Ind.txt"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 #cat("Reading network\n")
 #network<-read.csv(file.path(indir,"AllCodes_Network.txt"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 #cat("Reading network profiles\n")
 #network_profiles<-read.csv(file.path(indir,"AllCodes_network_indiv_profiles.txt"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 #cat("Reading pxdx\n")
 #pxdx<-read.csv(file.path(indir,"PXDX.txt"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
 #cat("Reading org\n")
 #org<-read.csv(file.path(indir,"Splitter_Org.txt"),row.names=NULL,sep="\t",stringsAsFactors=F,colClasses='character')
#}

####filter
indivs<-indivs[which(indivs$NPI %in% npis$NPI),]
network<-network[which(network[[paste("HMS_PIID",filter_column,sep="")]] %in% indivs$HMS_PIID),]
current_names<-colnames(network)

pxdx<-pxdx[which(pxdx$HMS_PIID %in% indivs$HMS_PIID),]

##add data for provider 1 and append _1 to new columns, to denote they refer to provider 1
if(all_codes==0){
provider1<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","COUNTY","PHONE1","PHONE2","FAX","NPI","GRP1_VOLUME_NATL_RANK","GRP1_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP2_ENTITIES","TERR_NUM_CONN_GRP2_ENTITIES")
}else{
colnames(network_profiles)[which(colnames(network_profiles)=="FAX")]<-"FAX1"
provider1<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","COUNTY","PHONE1","PHONE2","FAX","NPI","GRP1_VOLUME_NATL_RANK","GRP1_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP2_ENTITIES","TERR_NUM_CONN_GRP2_ENTITIES","FAX1","FAX2","NATL_NUM_CONN_ENTITIES","TERR_NUM_CONN_ENTITIES")
}

network<-merge(network,network_profiles[,which(colnames(network_profiles) %in% provider1)],by.x="HMS_PIID1",by.y="HMS_PIID")
if(all_codes==0){
colnames(network)[which(! colnames(network) %in% current_names & ! grepl("GRP",colnames(network)))]<-paste(colnames(network)[which(! colnames(network) %in% current_names & ! grepl("GRP",colnames(network)))],1,sep="_")
}else{
colnames(network)[which(! colnames(network) %in% current_names)]<-paste(colnames(network)[which(! colnames(network) %in% current_names)],1,sep="_")
}
current_names<-colnames(network)

##add data for provider 2 and append _2 to new columns
if(all_codes==0){
provider2<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","COUNTY","PHONE1","PHONE2","FAX","NPI","GRP2_VOLUME_NATL_RANK","GRP2_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP1_ENTITIES","TERR_NUM_CONN_GRP1_ENTITIES")
}else{
provider2<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","COUNTY","PHONE1","PHONE2","FAX","NPI","GRP1_VOLUME_NATL_RANK","GRP1_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP1_ENTITIES","TERR_NUM_CONN_GRP1_ENTITIES","FAX1","FAX2","NATL_NUM_CONN_ENTITIES","TERR_NUM_CONN_ENTITIES")
}
network<-merge(network,network_profiles[,which(colnames(network_profiles) %in% provider2)],by.x="HMS_PIID2",by.y="HMS_PIID")
if(all_codes==0){
colnames(network)[which(! colnames(network) %in% current_names & ! grepl("GRP",colnames(network)))]<-paste(colnames(network)[which(! colnames(network) %in% current_names & ! grepl("GRP",colnames(network)))],2,sep="_")
}else{
colnames(network)[which(! colnames(network) %in% current_names)]<-paste(colnames(network)[which(! colnames(network) %in% current_names)],2,sep="_")
}

##drop columns not needed for final deliverable
if(all_codes==0){
dropcols<-c('DERIVED_SPEC1_1','DERIVED_SPEC2_1','GENDER_1','DATE_BORN_1','FAX2_1','GRP1_VOLUME_NATL_RANK_1','GRP1_VOLUME_TERR_RANK_1','NATL_NUM_CONN_GRP2_ENTITIES_1','TERR_NUM_CONN_GRP2_ENTITIES_1','GRP2_VOLUME_NATL_RANK_1','GRP2_VOLUME_TERR_RANK_1','NATL_NUM_CONN_GRP1_ENTITIES_1','TERR_NUM_CONN_GRP1_ENTITIES_1','DERIVED_SPEC1_2','DERIVED_SPEC2_2','GENDER_2','DATE_BORN_2','FAX2_2','GRP1_VOLUME_NATL_RANK_2','GRP1_VOLUME_TERR_RANK_2','NATL_NUM_CONN_GRP2_ENTITIES_2','TERR_NUM_CONN_GRP2_ENTITIES_2','GRP2_VOLUME_NATL_RANK_2','GRP2_VOLUME_TERR_RANK_2','NATL_NUM_CONN_GRP1_ENTITIES_2','TERR_NUM_CONN_GRP1_ENTITIES_2')
}else{
dropcols<-c('DERIVED_SPEC1_1','DERIVED_SPEC2_1','GENDER_1','DATE_BORN_1','NATL_NUM_CONN_GRP2_ENTITIES_1','TERR_NUM_CONN_GRP2_ENTITIES_1','GRP2_VOLUME_NATL_RANK_1','GRP2_VOLUME_TERR_RANK_1','NATL_NUM_CONN_GRP1_ENTITIES_1','TERR_NUM_CONN_GRP1_ENTITIES_1','DERIVED_SPEC1_2','DERIVED_SPEC2_2','GENDER_2','DATE_BORN_2','NATL_NUM_CONN_GRP2_ENTITIES_2','TERR_NUM_CONN_GRP2_ENTITIES_2','GRP2_VOLUME_NATL_RANK_2','GRP2_VOLUME_TERR_RANK_2','NATL_NUM_CONN_GRP1_ENTITIES_2','TERR_NUM_CONN_GRP1_ENTITIES_2','FAX2_1','FAX2_2')
}
network<-network[,which(! colnames(network) %in% dropcols)]

####splitter
splitter_columns<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","HMS_POID","ORGTYPE","ORGNAME","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","PHONE1","PHONE2","FAX1","FAX2","NPI","IND_ORG_RANK","IND_ORG_TOTAL_PATIENTS","WORKLOAD")

#rename "IND_ORG_TOTAL_CLAIMS" to  "IND_ORG_TOTAL_PATIENTS". Header name with claim is an old error, want to clean it up if this is being shown to clients. changed 2/10/17 at ke's request - rdh
colnames(pxdx)[which(colnames(pxdx) == "IND_ORG_TOTAL_CLAIMS")]<-"IND_ORG_TOTAL_PATIENTS"
colnames(org)[which(colnames(org) == "ORG_TOTAL_CLAIMS")]<-"ORG_TOTAL_PATIENTS"
colnames(indivs)[which(colnames(indivs) == "IND_TOTAL_CLAIMS")]<-"IND_TOTAL_PATIENTS"

org_only_pxdx<-c("NPI","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","PHONE1","PHONE2","FAX1","FAX2")

pxdx<-merge(pxdx,indivs[,which(!colnames(indivs) %in% org_only_pxdx)],by="HMS_PIID")
pxdx<-merge(pxdx,org,by="HMS_POID")

#drop unused columns
pxdx<-pxdx[,which(colnames(pxdx) %in% splitter_columns)]

pxdx<-pxdx[splitter_columns]

if(all_codes==0){
network_order<-c("HMS_PIID1","FIRST_1","MIDDLE_1","LAST_1","SUFFIX_1","CRED_1","PRACTITIONER_TYPE_1","HMS_SPEC1_1","HMS_SPEC2_1","ADDRESS1_1","ADDRESS2_1","CITY_1","STATE_1","ZIP_1","ZIP4_1","COUNTY_1","PHONE1_1","PHONE2_1","FAX_1","NPI_1","GRP1_VOLUME_NATL_RANK","GRP1_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP2_ENTITIES","TERR_NUM_CONN_GRP2_ENTITIES","HMS_PIID2","FIRST_2","MIDDLE_2","LAST_2","SUFFIX_2","CRED_2","PRACTITIONER_TYPE_2","HMS_SPEC1_2","HMS_SPEC2_2","ADDRESS1_2","ADDRESS2_2","CITY_2","STATE_2","ZIP_2","ZIP4_2","COUNTY_2","PHONE1_2","PHONE2_2","FAX_2","NPI_2","GRP2_VOLUME_NATL_RANK","GRP2_VOLUME_TERR_RANK","NATL_NUM_CONN_GRP1_ENTITIES","TERR_NUM_CONN_GRP1_ENTITIES","NATL_SOR_VALUE","TERR_SOR_VALUE","PCT1","PCT2")
pxdx_order<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","HMS_POID","ORGNAME","ORGTYPE","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","PHONE1","PHONE2","FAX1","FAX2","NPI","ORG_NATL_RANK","ORG_TOTAL_PATIENTS","IND_ORG_RANK","IND_ORG_TOTAL_PATIENTS","WORKLOAD")
pxdx<-merge(pxdx,org[,c("HMS_POID","ORG_NATL_RANK","ORG_TOTAL_PATIENTS")],by="HMS_POID")
pxdx<-pxdx[pxdx_order]
}else{
network_order<-c("HMS_PIID1","FIRST_1","MIDDLE_1","LAST_1","SUFFIX_1","CRED_1","PRACTITIONER_TYPE_1","HMS_SPEC1_1","HMS_SPEC2_1","ADDRESS1_1","ADDRESS2_1","CITY_1","STATE_1","ZIP_1","ZIP4_1","COUNTY_1","PHONE1_1","PHONE2_1","FAX1_1","NPI_1","GRP1_VOLUME_NATL_RANK_1","GRP1_VOLUME_TERR_RANK_1","NATL_NUM_CONN_ENTITIES_1","TERR_NUM_CONN_ENTITIES_1","HMS_PIID2","FIRST_2","MIDDLE_2","LAST_2","SUFFIX_2","CRED_2","PRACTITIONER_TYPE_2","HMS_SPEC1_2","HMS_SPEC2_2","ADDRESS1_2","ADDRESS2_2","CITY_2","STATE_2","ZIP_2","ZIP4_2","COUNTY_2","PHONE1_2","PHONE2_2","FAX1_2","NPI_2","GRP1_VOLUME_NATL_RANK_2","GRP1_VOLUME_TERR_RANK_2","NATL_NUM_CONN_ENTITIES_2","TERR_NUM_CONN_ENTITIES_2","NATL_SOR_VALUE","TERR_SOR_VALUE","PCT1","PCT2")
pxdx_order<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","HMS_POID","ORGNAME","ORGTYPE","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","PHONE1","PHONE2","FAX1","FAX2","NPI","ORG_NATL_RANK","ORG_TOTAL_PATIENTS","IND_ORG_RANK","IND_ORG_TOTAL_PATIENTS","WORKLOAD")
pxdx<-merge(pxdx,org[,c("HMS_POID","ORG_NATL_RANK","ORG_TOTAL_PATIENTS")],by="HMS_POID")
pxdx<-pxdx[pxdx_order]
indivs_order<-c("HMS_PIID","FIRST","MIDDLE","LAST","SUFFIX","CRED","PRACTITIONER_TYPE","HMS_SPEC1","HMS_SPEC2","DERIVED_SPEC1","DERIVED_SPEC2","GENDER","DATE_BORN","NPI","ADDRESS1","ADDRESS2","CITY","STATE","ZIP","ZIP4","PHONE1","PHONE2","FAX1","FAX2","IND_NATL_RANK","IND_TOTAL_PATIENTS")
indivs<-indivs[indivs_order]
}
network<-network[network_order]

write.table(pxdx,file.path(outdir,"Splitter.tab"),row.names=F,sep="\t",quote=F,na="")
write.table(network,file.path(outdir,"InfNetwork.tab"),row.names=F,sep="\t",quote=F,na="")
write.table(indivs,file.path(outdir,"Indiv.tab"),row.names=F,sep="\t",quote=F,na="")









