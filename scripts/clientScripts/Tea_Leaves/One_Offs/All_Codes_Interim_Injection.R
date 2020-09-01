#####Input this information manually
date<-"2018_11_30"

# setwd("T:/Tea_Leaves/2018_04_30_PxDx_and_INA/2018_04_30_PxDx_Emdeon/All_Codes_PxDx/KE_Script_Test/config")

# Identify, import, and copy needed files ---------------------------------
##Name of AC bucket
ac_bucket<-"PT_HOA_E_exact"

##Parse month and year from date. Paste into format for All Codes path.
month_name<-month.name[as.integer(substr(date,6,7))]
year <- unlist(strsplit(date,"_"))[1]
ac_date<-paste0(substr(month_name,1,3),year)
ac_standard_path_cfg<-paste("/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes",ac_date,"config",sep="/")

##Copy All Codes folder for patching
ac_standard_path<-paste("/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes",ac_date,ac_bucket,sep="/")
file.copy(ac_standard_path,"..",recursive = T)

##Copy the original config files to another folder
dir.create("1_aggr_config_files")
files_to_copy<-c("codeGroupMembers.tab","codeGroupRules.tab","codeGroups.tab","jobVendorSettings.tab","settings.cfg")
file.copy(files_to_copy,"1_aggr_config_files")

##Read in pediatric All Codes config files
peds_cgr<-read.table("codeGroupRules.tab", header=T, sep="\t", quote="",as.is=T, na.strings="")
peds_jvs<-read.table("jobVendorSettings.tab", header=T, sep="\t", quote="",as.is=T, na.strings="")

##Read in standard All Codes config files
ac_cgr<-read.table(paste(ac_standard_path_cfg,"codeGroupRules.tab",sep="/"), header=T, sep="\t", quote="",as.is=T, na.strings="")
ac_jvs<-read.table(paste(ac_standard_path_cfg,"jobVendorSettings.tab",sep="/"), header=T, sep="\t", quote="",as.is=T, na.strings="")


# Inject config files -----------------------------------------------------

##Inject config files so patching can be run
##Concatenate codeGroupRules and jobVendorSettings files
comb_cgr<-rbind(peds_cgr,ac_cgr)
comb_jvs<-rbind(peds_jvs,ac_jvs)

##Find any lines that start with bucket name of interest (will find standard and peds bucket if named consistently)
comb_cgr_keep<-comb_cgr[grep(ac_bucket,comb_cgr$BUCKET_NAME),]
comb_jvs_keep<-comb_jvs[grep(ac_bucket,comb_jvs$BUCKET),]

##Clean up codeGroupRules file
comb_cgr_keep$REF_BUCKET_NAME<-NA

write.table(comb_cgr_keep,file="codeGroupRules.tab",col.names=T,row.names=F,sep="\t",quote=F,na="")
write.table(comb_jvs_keep,file="jobVendorSettings.tab",col.names=T,row.names=F,sep="\t",quote=F,na="")

##Copy injected config files for later use
dir.create("2_patching_config_files")
file.copy(files_to_copy,"2_patching_config_files")


# Final checks ------------------------------------------------------------

##Check that DONT_PATCH is set to N in settings file
peds_settings<-read.table(paste(ac_standard_path_cfg,"settings.cfg",sep="/"), header=F, sep="=", quote="",as.is=T, na.strings="")

peds_settings[grep("DONT_PATCH",peds_settings$V1),2]!="Y"


##Check for existence of manual_rules file
file.exists("../manual_rules.txt")


