###PXDX QA IN R
###Author: Lisa Estrella
#modified 9.27.2014 to handle QA of _fordelivery files from INA+PxDx integration
# process
# it checks for existence of indivs_px_fordelivery.tab
# or indivs_fordelivery.tab or individuals.tab to decide which scenario it is in

##Modified in June 2015 by Katie Eaton for various updates and process improvements.

#----------------------------------------------------------------------------------------------.
#----------------------------------------------------------------------------------------------.

##[3]LOAD IN TABLES FROM MILESTONES FOLDER.
  if(file.exists("individuals.tab")) {
pxdx	  <-	read.table("pxdx.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")
indivs  <-	read.table("individuals.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "FAX1"="character"),                         comment.char="", as.is=T, na.strings="")
orgs	  <-	read.table("organizations.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")
} else if(file.exists("indivs_px_fordelivery.tab")) {
pxdx      <-    read.table("pxdx_px_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T,na.strings="")
indivs  <-      read.table("indivs_px_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")
orgs      <-    read.table("orgs_px_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")

} else if(file.exists("indivs_fordelivery.tab")) {
pxdx      <-    read.table("pxdx_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")
indivs  <-      read.table("indivs_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")
orgs      <-    read.table("orgs_fordelivery.tab", header=T, sep="\t", quote="", colClasses=c("ZIP"="character", "ZIP4"="character", "PHONE1"="character", "PHONE2"="character", "FAX1"="character"), comment.char="", as.is=T, na.strings="")

}


sink("QA_output.txt")
cat("PxDx QA IN R\n")
cat("Author: Lisa Estrella\n")


#MOST IMPORTANT CHECKS.GIVES WARNING IF CRITERIA NOT MET.
cat("\n----------------------------------------------------------------------------------------------")
cat("\nDuplication Checks\n")
cat("----------------------------------------------------------------------------------------------\n")
##POIDs are unique
if(nrow(orgs) != length(unique(orgs$HMS_POID))) {
  cat("\n\t\t***WARNING: CHECK FAILED! There are non-unique POIDs in Organizations file.***\n")
} else {
  cat("\nPass: POIDs are unique.")
}

##PIIDs are unique
if(nrow(indivs) != length(unique(indivs$HMS_PIID))) {
  cat("\n\t\t***WARNING: CHECK FAILED! There are non-unique PIIDs in Individuals file.***\n")
} else {
  cat("\nPass: PIIDs are unique.\n")
}

##Each PIID at POID combination is unique 
#  Check to make sure you have a unique count of PIID at POID. PIIDs and POIDs can repeat but a
#  combination cannot.
poid_col<- grep("HMS_POID", colnames(pxdx))
piid_col<- grep("HMS_PIID", colnames(pxdx))
df <- pxdx[,c(piid_col,poid_col)]
uc1 <- nrow(df)
uc2 <- nrow(unique(df))
uc3 <- uc1-uc2
if (uc3 > 0) {
  cat("\n\t\t***WARNING: CHECK FAILED! The PIID at POID combination is NOT unique in PxDx file.***\n")
} else {
  cat("Pass: PIID at POID combination is unique.\n")
}


#PASS/FAIL CHECKS
cat("\n----------------------------------------------------------------------------------------------")
cat("\nPass or Fail Checks\n")
cat("----------------------------------------------------------------------------------------------\n")

##Each PIID has only one Practitioner National Rank per category (bucket)
#  PIIDs should not have different PHYSICIAN NATIONAL ranks per bucket.  Where a Physician shows up in
#	the PxDx table more than 1 time, the Physician National rank should always be the same.
col_natl  		<- grep("NATL", colnames(pxdx))
col_rank 			<- grep("RANK", colnames(pxdx))
col_natl_rank		<- intersect(col_rank, col_natl)
col_prac1			<- grep("PRACTITIONER", colnames(pxdx))
col_prac2			<- grep("HOME_PRACTITIONER", colnames(pxdx))
col_prac			<- union(col_prac1, col_prac2)
col_prac_natl_rank 	<- intersect (col_natl_rank, col_prac)
poid_col 			<- grep("HMS_POID", colnames(pxdx))
piid_col			<- grep("HMS_PIID", colnames(pxdx))
col_fac1			<- grep("FAC", colnames(pxdx))
col_fac2			<- grep("SUPPL", colnames(pxdx))
col_fac			<- union(col_fac1, col_fac2)
col_fac_natl_rank		<- intersect(col_natl_rank,col_fac)
col_fac_rank		<- intersect(col_fac, col_rank)
col_prac_fac_rank		<- intersect(col_fac_rank,col_prac)
col_wl1			<- grep("WORKLOAD", colnames(pxdx))
col_wl2			<- grep("SHARE", colnames(pxdx))
col_wl			<- union(col_wl1, col_wl2)


check_only_one_prac_natl_rank <- function(mat,i,piid_col) {
  x <- unique(mat[,c(i,piid_col)])
  (range(table(x[,2])))
}
for (c in col_prac_natl_rank) {
  natl_rank_piid_check<-check_only_one_prac_natl_rank(pxdx,c,piid_col)
}


pass<-as.integer(c(1,1))
if(identical(natl_rank_piid_check,pass)==TRUE){
  cat("\nPass: Each PIID has only one Practitioner National Rank per bucket.\n")
  }else{
  cat("\n\t\t***WARNING: CHECK FAILED! At least one PIID has more than one Practitioner National Rank in a bucket.***\n")
}


##Each PIID has only one Practitioner Facility Rank per category (bucket) per POID
#	PIIDs should not have different PHYSICIAN FACILITY ranks per POID. There should only be one
#	instance of a Physician Facility Rank/POID combination in the PxDx table.
check_only_one_prac_fac_rank <- function(i,piid_col,poid_col) {
  y<-unique(pxdx[,c(i,piid_col,poid_col)])
  z<-paste(y[,2],y[,3],sep=":")
  (range(table(z)))
}
for(c in col_prac_fac_rank) {
  prac_fac_rank_check<-check_only_one_prac_fac_rank(c,piid_col,poid_col)
}
if(identical(prac_fac_rank_check,pass)==TRUE){
  cat("Pass: Each PIID has only one Practitioner @ Facility Rank per bucket.")
}else{
  cat("\n\t\t***WARNING: CHECK FAILED! At least one PIID has more than one Practitioner @ Facility Rank in a bucket.***\n")
}


##Each PIID has only one Workload per category (bucket) per POID
#	PIIDs should not have different workload per POID.  There should only be 1 instance of a
#	HCPs workload per POID in the PxDx table.
if(length(col_wl) > 0) {
  for(c in col_wl) 	{
  workload_check<-check_only_one_prac_fac_rank(c,piid_col,poid_col)
  }
}
if(identical(workload_check,pass)==TRUE){
  cat("\nPass: Each PIID @ POID combination has one workload per bucket.\n")
}else{
  cat("\n\t\t***WARNING: CHECK FAILED! At least one PIID @ POID combination has more than one workload in a bucket.***\n")
}


##Each POID has only one Facility National Rank per category (bucket)
#	Each POID should not have the SAME FACILITY NATIONAL ranks per bucket.  Where a Facility shows up
#	in the PxDx table more than 1 time, the Facility National rank should always be the same.
col_fac_natl_rank <- intersect(col_natl_rank,col_fac)
check_only_one_fac_natl_rank <- function(mat,i,poid_col) {
  x <- unique(mat[,c(i,poid_col)])
  (range(table(x[,2])))
}
for (c in col_fac_natl_rank) {
  fac_natl_rank_check<-check_only_one_fac_natl_rank(pxdx,c,poid_col)
}

if(identical(fac_natl_rank_check,pass)==TRUE){
  cat("Pass: Each POID has only one Facility National Rank per bucket.")
}else{
  cat("\n\t\t***WARNING: CHECK FAILED! At least one POID has more than one Facility National Rank in a bucket.***\n")
}

##Each PIID Practitioner National Rank in PxDx matches Individuals Table
#  Perform a comparison between the PxDx table to confirm that all Physician National Ranks in the Indiv
#	Table are the same for each PIID in the PxDx table. If you add the counts from the missing PIIDs (see
#	check for "Compare PIIDs in PxDx to PIIDs in Individuals table") in the PxDx table you should get the
#	number of PIIDs in your individuals table 

  
for (c in col_prac_natl_rank) {
  pxdx.prac_natl_rank 	<- pxdx[,c("HMS_PIID",colnames(pxdx)[c])]
  indivs.prac_natl_rank 	<- indivs[,c("HMS_PIID",colnames(pxdx)[c])]
  compare <- merge(pxdx.prac_natl_rank,indivs.prac_natl_rank,by.x=1,by.y=1)
  matched <- which(compare[,2] != compare[,3])
  if(length(matched) > 0) {
    cat("\n\t\t***WARNING: CHECK FAILED! Practitioner National Rank is not matched for these PIIDs:***\n")
    cat("\n")
    print(compare[matched,1])
    cat("\n")
  }
  if(length(matched) <= 0){
    cat("\nPass: Practitioner National Ranks in PxDx match Individuals Table.")
    }
}


##Each POID Facility National Rank in PxDx matches Organization Table
#	Perform a comparison between the PxDx table to confirm that all Facility National Ranks in the
#	Organizations Table are the same for each POID in the PxDx table. If you add the counts from the
#	missing POIDs (See check in ROW 31 in Excel checklist) in the PxDx table you should get the number of
#	POIDs in your Organizations table .
for (c in col_fac_natl_rank) {
  pxdx.fac_natl_rank 	<- pxdx[,c("HMS_POID",colnames(pxdx)[c])]
  orgs.fac_natl_rank 	<- orgs[,c("HMS_POID",colnames(pxdx)[c])]
  compare <- merge(pxdx.fac_natl_rank,orgs.fac_natl_rank,by.x=1,by.y=1)
  matched <- which(compare[,2] != compare[,3])
  if(length(matched) > 0) {
    cat("\t\t***WARNING: CHECK FAILED! Facility National Rank is not matched for these PIIDs:***\n")
    cat("\n")
    print(compare[matched,1])
    cat("\n")
 }
  if(length(matched) <= 0){
    cat("\nPass: The Facility National Ranks in PxDx match Organizations Table.")
}
}






##All PIIDs in PxDx table are in Indivs table
indivs.piids <- unique(indivs$HMS_PIID)
pxdx.piids <- unique(pxdx$HMS_PIID)
x1 <- length(indivs.piids)
x2 <- length(pxdx.piids)
x3 <- length(setdiff(indivs.piids, pxdx.piids))
x4 <- length(setdiff(pxdx.piids,indivs.piids))
pxdx_indiv<-((x2-x4)/x2)*100

if(pxdx_indiv==100){
  cat("\nPass: All PIIDs in PxDx table are in Individuals table.\n")
}else{
  cat("\t\t**WARNING: CHECK FAILED! At least one PIID in PxDx table is not in Individuals table.\n")
}



##All POIDs in PxDx table are in Orgs table
orgs.poids <- unique(orgs$HMS_POID)
pxdx.poids <- unique(pxdx$HMS_POID)

t1 <- length(orgs.poids )
t2 <- length(pxdx.poids )
t3 <- length(setdiff(orgs.poids , pxdx.poids ))
t4 <- length(setdiff(pxdx.poids ,orgs.poids ))
pxdx_org<-((t2-t4)/t2)*100

if(pxdx_indiv==100){
  cat("Pass: All POIDs in PxDx table are in Organizations table.\n")
}else{
  cat("\t\t**WARNING: CHECK FAILED! At least one POID in PxDx table is not in Organizations table.\n")
}

  
  dir<-getwd()
  
  qacheck<-grepl("QA",dir)
  milestonescheck<-grepl("milestones",dir)
  
    
 #If unning script from QA folder 
  if(qacheck == TRUE) {   
    ## Checks all subfolders for projections files and that none are empty.
    ## Assumes you are running from the QA folder.
    basename.matches<-list.files("../Projections",pattern='*_projections.txt',recursive=TRUE,full.names=TRUE)
    basename.matches.home<-list.files("../Projections",pattern='*_projection.txt',recursive=TRUE,full.names=TRUE)
    basename.all<-union(basename.matches,basename.matches.home)
    num<-length(basename.all)  
    filesize<-file.info(basename.all[1:num])$size
    sum_filesize<-sum(filesize==0)
    if(sum_filesize==0){
      cat("Pass: All projections files contain data.")
    } else {
      cat("\n\t\tWARNING: CHECK FAILED! The following projection files are empty:\n\n")
      df.filesize<-as.data.frame(t(rbind(basename.all,filesize)))
      df.emptyfile<-df.filesize[df.filesize$filesize==0,]
      colnames(df.emptyfile)<-c("file","size")
      print(df.emptyfile, row.names=F)
    }
    ##Check that all needed projection files were created.
    cat("\n\nReview projection file list against settings. If an expected file is missing, there is a problem.\n")
    print(basename.all,quote=F,row.names=F)
  }
  
#If running script from milestones folder (combined project for LS)
if(milestonescheck==TRUE)  {
  setwd("..")
  dir_new<-getwd()
  list<-list.dirs('.', recursive=FALSE)
  
  subfolder<-list.dirs(dir_new,recursive=T)
  sub_proj<-grepl("/Projections/",subfolder)
  projfolders<-subfolder[sub_proj]
  
  basename.matches<-list.files(projfolders,pattern='*_projections.txt',recursive=TRUE,full.names=TRUE)
  basename.matches.home<-list.files(projfolders,pattern='*_projection.txt',recursive=TRUE,full.names=TRUE)
  basename.all<-union(basename.matches,basename.matches.home)

  num<-length(basename.all)  
  
  filesize<-file.info(basename.all[1:num])$size
  sum_filesize<-sum(filesize==0)
  if(sum_filesize==0){
    cat("Pass: All projections files contain data.")
  } else {
    cat("\n\t\tWARNING: CHECK FAILED! The following projection files are empty:\n\n")
    df.filesize<-as.data.frame(t(rbind(basename.all,filesize)))
    df.emptyfile<-df.filesize[df.filesize$filesize==0,]
    colnames(df.emptyfile)<-c("file","size")
    print(df.emptyfile, row.names=F)
  }
  setwd("./milestones")
  ##Check that all needed projection files were created.
  cat("\n\nReview projection file list against settings. If an expected file is missing, there is a problem.\n")
  print(basename.all,quote=F,row.names=F)
}

if(milestonescheck==FALSE & qacheck==FALSE){
  cat("WARNING: CHECK SKIPPED! This script was not run from the QA or milestones folder. Files in Projections folder were not checked.\n")
  }

cat("\n----------------------------------------------------------------------------------------------\n")
cat("Record Counts for All Tables\n")
cat("----------------------------------------------------------------------------------------------\n")
cat("\nNumber of records in PXDX table:\n")
(nrow(pxdx))
cat("\nNumber of records in INDIVIDUALS table:\n")
nrow(indivs)
cat("\nNumber of records in ORGANIZATIONS table:\n")
nrow(orgs)


  cat("\n\n----------------------------------------------------------------------------------------------\n")
  cat("PIID and POID Comparisons\n")
  cat("----------------------------------------------------------------------------------------------\n")
  ##Compare PIIDs in PxDx to PIIDs in Individuals table
  #  All PIIDs in the PxDx table should appear in the Individuals Table. If they don't consult
  #  Dilip. There will be some PIIDs in the Individuals table that do not appear in the PxDx table.
  #	Make a count of how many PIIDs are missing from the PxDx table.
  
  # cat("\nNumber of unique PIIDs in Individuals table:\n")
  # length(indivs.piids)
  
  cat("\nNumber of unique PIIDs in PxDx table:\n")
  length(pxdx.piids)
  
  cat("\nPercent of PIIDs in Individuals table existing in PxDx table:\n")
  ((x1-x3)/x1 *100)
  cat("*Note: This result will not always be 100%. There may be some PIIDs in the Individuals table that do not appear in the PxDx table.\n")
  
  
  ##Compare POIDs in PxDx to POIDs in Organization table
  #  All POIDs in the PxDx table should appear in the Organizations Table. If they don't consult
  #	Dilip. There will be some POIDs in the Organizations table that do not appear in the PxDx table.
  #	Make a count of how many POIDs are missing from the PxDx table.
  
  
  # cat("\nNumber of unique POIDs in Organizations table:\n")
  # length(orgs.poids)
  
  cat("\nNumber of unique POIDs in PxDx table:\n")
  length(pxdx.poids)
  
  cat("\nPercent of POIDs in Organizations table existing in PxDx table:\n")
  ((t1-t3)/t1 *100)
  cat("*Note: This result will not always be 100%. There may be some POIDs in the Organizations table that do not appear in the PxDx table.\n")
  
  
  
  cat("\n\n----------------------------------------------------------------------------------------------\n")
  cat("PxDx\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  
  
  ###Fill Rates
  #	If any of these fields are missing look at the ranks of the POID. If ranks are 6 and above, investigate.
  #	If 5 and below, OK to remove  from the PxDx table.  Maintain inventory of removed records in the Changes
  #	to Universe tab of this document.  Make sure that removing the record doesn't create a discrepancy between
  #	the PxDx table and the Organization Table or any other supporting tables (if relevant). Track list of updates
  #	to POIDs  in Changes to Universe Tab.  
  #####	100% Fill of Last Name
  #####	100% Fill of First Name
  #####	POIDs Organization Name Fill Rate
  #####	POIDs 100% Fill of Address 1
  #####	POIDs 100% Fill of City
  #####	POIDs 100% Fill of State
  #####	POIDs 100% Fill of Zip 5
  #####	POIDS 100% Fill rate of Org Type
  cat("\nFill Rates for PxDx Table\n\n")
  #signif(100*apply(pxdx,2,function(x) length(which(!is.na(x) & x != "")))/nrow(pxdx),3)
  
  
  pxdx_fill<-colSums(!is.na(pxdx))
  
  pxdx_fill2<-signif((pxdx_fill/nrow(pxdx))*100,5)
  
  pxdx_fill3<-as.data.frame(pxdx_fill2)
  
  pxdx_fill3[,2]<-"->"
  
  pxdx_fill4<-pxdx_fill3[,c(2,1)]
  
  write.table(format(pxdx_fill4, drop0trailing=FALSE),file='QA_output.txt',,append=T,quote=F,col.names=F) 
  
  sink("QA_output.txt",append=T)
  
  ##Middle Name Makes sense (No credential as middle name)
  #  This check will double-check middle name field for "MEDICAL", "FAMILY", "MEDICINE",
  #  "ORTHOPDC", "ORTHOPEDIC", and "ORTHOPAEDIC". Updates can be made as other values are
  #	found to be invalid.
  
  pxdx$MIDDLE[pxdx$MIDDLE == "MEDICAL"] <- ""
  pxdx$MIDDLE[pxdx$MIDDLE == "FAMILY"] <- ""
  pxdx$MIDDLE[pxdx$MIDDLE == "MEDICINE"] <- ""
  pxdx$MIDDLE[pxdx$MIDDLE == "ORTHOPDC"] <- ""
  pxdx$MIDDLE[pxdx$MIDDLE == "ORTHOPEDIC"] <- ""
  pxdx$MIDDLE[pxdx$MIDDLE == "ORTHOPAEDIC"] <- ""
  
  cat("\n---------------------------------------------------------------------------------------------\n")
  cat("Individuals (Practitioner Profile)\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  
  ##Fill Rates
  #	100% Fill of Last Name
  #	100% Fill of First Name
  #	100% Fill of Address 1
  #	100% Fill of City
  #	100% Fill of State
  #	100% Fill of Zip 5
  #	Fill Rate of Phone 1 (if less than 75% - Investigate)
  #	Fill Rate of Fax 1 (if less than 50% - Investigate)
  #	Individual Identifiers (NPI #) Fill Rate
  #	Individual Identifiers (DEA #) Fill Rate
  #	Individual Identifiers (UPIN #) Fill Rate
  #	Individual Identifiers (State License #) Fill Rate
  #	Individual Identifiers (Tax ID) Fill Rate
  #	Individual Identifiers (Sanctions) Make Sense
  #	Individual Identifiers (Clinical Trail Profile) Make Sense
  #	Individual Identifiers (Graduation Year) Make Sense
  #	Individual Identifiers (School) Fill Rates
  cat("\nFill Rates for Individuals Table\n\n")
  #signif(100*apply(indivs,2,function(x) length(which(!is.na(x) & x != "")))/nrow(indivs),3)
  
  indivs_fill<-colSums(!is.na(indivs))
  
  indivs_fill2<-signif((indivs_fill/nrow(indivs))*100,5)
  
  indivs_fill3<-as.data.frame(indivs_fill2)
  
  indivs_fill3[,2]<-"->"
  
  indivs_fill4<-indivs_fill3[,c(2,1)]
  
  write.table(format(indivs_fill4, drop0trailing=FALSE),file='QA_output.txt',,append=T,quote=F,col.names=F) 
  
  sink("QA_output.txt",append=T)
  
  ##Practitioner Type Make Sense
  #	Remove Dentists and Vets if rank 5 and below.  Maintain inventory of removed records in the
  #	Changes to Universe tab of this document.  Make sure that removing record doesn't create a
  #	discrepancy between the PxDx table and the Individual/Organization Table or any other supporting
  #	tables (if relevant).  If ranks are 6 and above, investigate.
  
  #	Before Removing Dentists perform some research on the codes you are using the deliverable i.e.
  #	there might be a certain Tumor of the mouth associated with an Oncology disease code that you are
  #	using in your deliverable that dentists could specialize in. If there is pick a few high ranking
  #	dentists and perform web based research. If you can defend them being in the deliverable keep. If
  #	not remove.
  cat("\n\nPractitioner Type\n")
  
  cat("\n\tAdditional rank information by practitioner type, specialty, and org type is available in practtypebyrank.txt file.\n\n")
  
  
  cat("\tTable of ALL Practitioner types:\n")
  sort(table(indivs$PRACTITIONER_TYPE), decreasing=TRUE) 
  
  ##HMS Spec 1 Makes Sense
  #	When specialty filtering is used to create the deliverable, must confirm that specialties align to the
  #	requirements.  If no specialty filtering, use judgement, when in doubt, consult sales rep.
  
  cat("\n\nTen most frequent HMS Spec1 types:\n")
  sort(table(indivs$HMS_SPEC1), decreasing=TRUE)[1:10]
  
  
  ##HMS Spec 2 Makes Sense
  #	When specialty filtering is used to create the deliverable, must confirm that specialties align to the
  #	requirements.  If no specialty filtering, use judgement, when in doubt, consult sales rep.
  
  cat("\n\nTen most frequent HMS Spec2 types:\n")
  sort(table(indivs$HMS_SPEC2), decreasing=TRUE)[1:10]
  
  
  ##Credentials Make Sense (if they are present)
  cat("\n\nTen most frequent credential types:\n")
  sort(table(indivs$CRED), decreasing=TRUE)[1:10]
  
  dentist <- grep("Dentist",indivs$PRACTITIONER_TYPE)
  #This grabs whatever name you specify from the Practitioner Type field!!
  cat("\n\tNumber of Dentists in this deliverable:")
  cat("\t", length(dentist),"\n")
  
  col_natl      <- grep("NATL", colnames(indivs))
  col_rank       <- grep("RANK", colnames(indivs))
  col_natl_rank		<- intersect(col_rank, col_natl)
  col_prac			<- grep("PRACTITIONER", colnames(indivs))
  col_prac_natl_rank 	<- intersect (col_natl_rank, col_prac)
  indiv_rank<-cbind(indivs$HMS_PIID,indivs$PRACTITIONER_TYPE,indivs$HMS_SPEC1,indivs[col_natl_rank])
  
  if(length(dentist)>0){
    cat("\n\tNational Ranks of Dentists in this deliverable (top row=rank, bottom row=count):\n")
    dentist_rank<-indiv_rank[dentist,]
    ncol_dentist<-ncol(dentist_rank)
    print(table(dentist_rank[,ncol_dentist]))
  }
  
  
  vet <- grep("Vet",indivs$PRACTITIONER_TYPE)
  cat("\n\tNumber of Vets in this deliverable:")
  #This grabs whatever name you specify from the Practitioner Type field!!
  cat("\t",length(vet),"\n\n")
  
  
  if(length(vet)>0){
    cat("\n\tNational Ranks of Vets in this deliverable (top row=rank, bottom row=count):\n")
    vet_rank<-indiv_rank[vet,]
    ncol_vet<-ncol(vet_rank)
    print(table(vet_rank[,ncol_vet]))
  }
  
  
  
  sink("practtypebyrank.txt")
  cat("Specialty for Top Decile Ranking PIIDs\n")
  
  colnames(indiv_rank)[2]<-"PRACTITIONER_TYPE"
  colnames(indiv_rank)[4]<-"RANK"
  colnames(indiv_rank)[3]<-"SPECIALTY"
  toprankpiids<-subset(indiv_rank,indiv_rank$RANK >= 8)
  toprankpiids<-droplevels(toprankpiids)
  table(toprankpiids$SPECIALTY, toprankpiids$RANK)
  
  cat("\n\nOrg Type for Top Decile Ranking POIDs\n")  
  
  orgs_rank<-cbind(pxdx$HMS_POID,pxdx$ORGTYPE,pxdx[col_fac_natl_rank])
  colnames(orgs_rank)[2]<-"ORGTYPE"
  colnames(orgs_rank)[3]<-"RANK"
  toprankpoids<-subset(orgs_rank,orgs_rank$RANK >= 8)
  toprankpoids<-droplevels(toprankpoids)
  table(toprankpoids$ORGTYPE, toprankpoids$RANK)
  
  
  cat("\n\nPractitioner Type by National Rank\n")
  table(indiv_rank$PRACTITIONER_TYPE, indiv_rank$RANK)
  
  
  sink("QA_output.txt",append=T)
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("Organizations (Facility Profile)\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  
  ##Fill Rates
  #	100% Organization Name Fill Rate
  #	100% Fill of Address 1
  #	100% Fill of City
  #	100% Fill of State
  #	100% Fill of Zip 5
  #	100% Fill rate of Org Type
  #   Facility Identifiers (NPI #) Fill Rate
  #	Facility Identifiers (DEA #) Fill Rate
  #	Facility Identifiers (Tax ID) Fill Rate
  #	Facility Identifiers (POS) Fill Rate
  cat("\nFill Rates for Organizations Table\n\n")
  #signif(100*apply(orgs,2,function(x) length(which(!is.na(x) & x != "")))/nrow(orgs),3)
  
  orgs_fill<-colSums(!is.na(orgs))
  
  orgs_fill2<-signif((orgs_fill/nrow(orgs))*100,5)
  
  orgs_fill3<-as.data.frame(orgs_fill2)
  
  orgs_fill3[,2]<-"->"
  
  orgs_fill4<-orgs_fill3[,c(2,1)]
  
  write.table(format(orgs_fill4, drop0trailing=FALSE),file='QA_output.txt',,append=T,quote=F,col.names=F) 
  
  sink("QA_output.txt",append=T)
  
  cat("\n\nTen Most Frequent Org Types:\n")
  sort(table(orgs$ORGTYPE), decreasing=TRUE)[1:10]
  
  
  
  
  
  cat("\n\nQA SCRIPT COMPLETE.")
  sink()
  
  
  ####Non-automated checks moved to separate txt file.
  
  sink("manual_checklist.txt")
  
  
  cat("File Integrity\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  ##File record layout matches proposal.
  #  If provided, best practice to use Contract/Signed Proposal.
  #  Be sure to check for Specialty/Physician Filtering in the Proposal
  #	or any other type of special filter (i.e. Age Filter).
  cat("\nDoes the file layout match the SOW?\n")
  
  ##File layout matches delivery document unless otherwise instructed.
  #	If project is a refresh be sure to consult past delivery documents
  #	to make sure file layouts are the same as client expectations.
  cat("Does the file layout match the delivery document?\n\n")
  
  
  
  cat("----------------------------------------------------------------------------------------------\n")
  cat("Projections Setup\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  ##Make sure the Jobs you ran in SORY have the correct information from the SOW or Documentation from Sales.
  #	Check IP/OP/OFF Settings.
  #	Att/Op/Other.
  #	Confirm pulling right Counts (Pat/Proc/Claims).
  cat("\nDo your jobs have the correct information from the SOW?\n")
  cat("\ta. Are your settings of care properly selected?\n")
  cat("\tb. Have you selected the correct physician types (attending, operating, other)?\n")
  cat("\tc. Did you pull by the right counts (patients, claims, or procedures)?\n")
  
  ##Make sure DX/PX codes are correct 
  #	Make sure you typed codes in correctly from SOW. Make sure you labeled your Dx and PX codes
  #	correctly. Also note that an ICD9 code can be a Dx (XXX._ _) (IP/OP/OFF) or PX (XX._ _) (IP only)
  #	and that a CPT Code(XXXXX) (OP/OFF) can only be a Px code.
  cat("Are your Dx/Px codes correct?\n")
  
  ##Vintage Check 
  #	Make sure the same vintage is used across all bucket runs.
  cat("Are you using the same vintage for all buckets?\n")
  
  
  ##Buckets are labeled properly with diagnosis/procedure bucket name in delivery tables
  #	Make sure to update across all buckets so that the client can actually understand what the
  #	bucket represents. If providing counts, make sure that the column reflects the type of
  #	count (i.e. claims/procedure/patient).
  cat("Are buckets labelled properly with diagnosis/procedure bucket name in delivery tables?\n")
  
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("Co-occur or Combine Setup\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  ##Bucket Check
  #  Make sure buckets are run individually. If you have a bucket that contains both a Px and a
  #	Dx code. Confirm you run them seperately in SORY and then perform the UNION step once they
  #	are finished running to get your one bucket.
  cat("\nCheck all buckets, especially any unions you may have had to set-up.\n")
  
  ##Co-Occur Bucket Check 
  #	If you have co-occuring buckets, be sure to co-occur them correctly. You want to make sure
  #	you run your main bucket codes seperately and then run a co-occur with the co-occur step in
  #	SORY (unprojected only) 
  cat("If there are co-occurring buckets, double check this process again.\n")
  
  
  ##Combine Mutiple Buckets in deliverable 
  cat("If applicable, make sure that all of your buckets for this deliverable have gone through the combine step in SoRY.\n")
  
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("For Refreshes: Compare to Prior Deliverable\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  ##Number of Tables is the same as Prior Deliverables
  cat("\nIs the number of tables the same as the prior deliverable?\n")
  
  ##Names of Tables is the same as Prior Deliverables
  cat("Are the table names the same as the prior deliverable?\n")
  
  ##Compare previous deliverable PxDx table to current deliverable PxDx table.
  cat("Compare previous deliverable PxDx table to current deliverable PxDx table.\n") 
  cat("\tIf there is a previous deliverable, you may want to use R code to produce an 11x11 table to compare projects. Consult Dilip.\n")
  
  ##Compare the number of PIIDS and POIDS prev versus current 
  #	If “significant” delta investigate via checking PIID/POIDs that have dropped out and ask Dilip/Developer
  cat("Compare the number of PIIDS and POIDS in previous versus current deliverable.\n") 
  
  
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("Rank Checks\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  
  ##When ranks are being run sub-national (like territory level deciles) – ensure that the ranks are not
  ##exactly the same for all records.
  cat("\nIf you have territory ranks, ensure that the natl and terr ranks are not the same for all records.")
  
  
  ##When specialty filtering is applied ensure that the ranks are not exactly the same for all records.
  #	If provided, compare the ranks in the filtered bucket to any non filtered/different filter bucket
  #	to ensure they are not exactly the same for every PIID/POID.
  cat("\nIf you have specialty filtering, ensure that ranks are not exactly the same for all records (compare ranks in filtered bucket to non-filtered bucket).")
  
  
  ##Practitioner National Rank is a numeric field per category (bucket)
  cat("\nEnsure that the following are numeric fields: Practitioner National Rank, Practitioner Facility Rank, and Facility National Rank.\n")
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("Field Checks\n")
  cat("----------------------------------------------------------------------------------------------\n")
  
  
  
  ##POIDS Facility Type 
  #  If project is a refresh and Facility Type was previously delivered continue to deliver
  #	Facility Type. Usually newer project will get the Org
  #	Type versus the Facility Type. Do not deliver both unless contract and Sales request it.
  cat("\nCheck delivery of Fac Type versus Org Type. Org Type is our standard. Do not deliver both.\n")
  
  ##Birthdates make sense
  #  Remove any value less than 1935.
  cat("If you have birth dates, do they make sense? Remove values less than 1935.\n")
  
  
  
  cat("\n----------------------------------------------------------------------------------------------\n")
  cat("Decile Distribution Graphs\n")
  cat("----------------------------------------------------------------------------------------------\n")
  cat("*NOTE: If you see Column Name:  blank or NA, you have an error.\n\n")
  
  
  ##Check Distribution of PIIDs by Physican National Rank per Decile
  # Group By and Count each bucket.  The distribution should have fewest PIIDs @ rank 10, increasing
  #  as the ranks decrease. If the distribution is off SIGNIFICANTLY  Review the Min/Max Table and make
  #	sure counts line up. If the counts are low due to the nature of the buckets your pulling - okay to
  #	keep this way in deliverable. Also consider Tie Breaking Rationality as a justification of the
  #	distribution being slightly off.
  
  #	Confirm that full decile distribution is achieved. If a few numbers are missing i.e. a 2 or 6 but
  #	all else is in line - okay to deliver - if due to the nature of the buckets you are pulling. If
  #	more than 2 numbers are missing and a Quintile looks promising discuss with Sales and Dilip and
  #	perform a Quintile. If more than 5 numbers are missing and a trecile looks more promising discuss
  #	with Dilip/Sales and perform Trecile. 
  cat("Check distribution of PIID Physician National Rank in PXDX_TABLE_Check_dist_PIIDs_PRACTITIONER_NATL_RANK.pdf.\n")
  cat("\n")
  
  fixedranks <- (1:10)
  #convert rank table into data form
  pdf("PXDX_TABLE_Check_dist_PIIDs_PRACTITIONER_NATL_RANK.pdf",onefile=T)
  
  col_natl    	<- grep("NATL", colnames(pxdx))
  col_rank 			<- grep("RANK", colnames(pxdx))
  col_natl_rank		<- intersect(col_rank, col_natl)
  col_prac1  		<- grep("PRACTITIONER", colnames(pxdx))
  col_prac2			<- grep("HOME_PRACTITIONER", colnames(pxdx))
  col_prac			<- union(col_prac1, col_prac2)
  col_prac_natl_rank   <- intersect (col_natl_rank, col_prac) 
  piid_col<- grep("HMS_PIID", colnames(pxdx))
  
  for (c in col_prac_natl_rank) {
    cat("\tColumn Name: ", colnames(pxdx)[c],"\n")
    d <- unique(pxdx[,c(piid_col,c)])
    ranked_dist <- table(d[,2])
    ranked_dist_df <- as.data.frame(ranked_dist)
    mer <- merge(fixedranks, ranked_dist_df, by.x=1, by.y=1, all.x=T)
    ex <- barplot(mer$Freq,main=sub("_PRACTITIONER_NATL_RANK", "", colnames(pxdx)[c]),names.arg=mer$x)
    text(ex, mer$Freq+3, format(mer$Freq), xpd=TRUE, col="blue")
  }
  null_device<-dev.off()
  
  
  ##Check Distribution of POIDs by Facility National Rank per Decile
  #	Group By and Count each bucket.  The distribution should have fewest POIDs @ rank 10, increasing
  #	as the ranks decrease. If the distribution is off SIGNIFICANTLY  Review the Min/Max Table and make
  #	sure counts line up. If the counts are low due to the nature of the buckets your pulling - okay to
  #	keep this way in deliverable. Also consider Tie Breaking Rationality as a justification of the
  #	distribution being slightly off. 
  
  #	Confirm that full decile distribution is achieved. If a few numbers are missing i.e. a 2 or 6 but
  #	all else is in line - okay to deliver - if due to the nature of the buckets you are pulling. If
  #	more than 2 numbers are missing and a Quintile looks promising discuss with Sales and Dilip and
  #	perform a Quintile. If more than 5 numbers are missing and a trecile looks more promising discuss
  #	with Dilip/Sales and perform Trecile. 
  cat("\nCheck distribution of POID Facility National Rank in PXDX_TABLE_Check_dist_POIDs_FAC_NATL_RANK.pdf.\n")
  cat("\n")
  pdf("PXDX_TABLE_Check_dist_POIDs_FAC_NATL_RANK.pdf",onefile=T)
  for (c in col_fac_natl_rank) {
    cat("\tColumn Name: ", colnames(pxdx)[c],"\n")
    d <- unique(pxdx[,c(poid_col,c)])
    ranked_dist <- table(d[,2])
    ranked_dist_df <- as.data.frame(ranked_dist)
    mer <- merge(fixedranks, ranked_dist_df, by.x=1, by.y=1, all.x=T)
    ex <- barplot(mer$Freq,main=sub("_FAC_NATL_RANK", "", colnames(pxdx)[c]),names.arg=mer$x)
    text(ex, mer$Freq+3, format(mer$Freq), xpd=TRUE, col="blue")
  }
  null_device<-dev.off()
  
  
  ##Check Distribution of PIIDs by Physican National Rank per Decile
  #  Group By and Count each bucket.  The distribution should have fewest PIIDs @ rank 10, increasing as
  #  the ranks decrease. If there are a few numbers out of order i.e. (10,9,8,6,7,5,4,2,3,1) Review the
  #	Min/Max Table and make sure counts line up. If the counts are low due to the nature of the buckets your
  #	pulling - okay to keep this way in deliverable
  
  #	Confirm that full decile distribution is achieved. If a few numbers are missing i.e. a 2 or 6 but all else
  #	is in line - okay to deliver - if due to the nature of the buckets you are pulling. If more than 2 numbers
  #	are missing and a Quintile looks promising discuss with Sales and Dilip and perform a Quintile. If more than
  #	5 numbers are missing and a trecile looks more promising discuss with Dilip/Sales and perform Trecile. 
  cat("\nCheck distribution of PIID Physician National Rank in INDIVS_TABLE_Check_dist_PIIDs_PRACTITIONER_NATL_RANK.pdf.\n\n")
  
  col_natl    	<- grep("NATL", colnames(indivs))
  col_rank 			<- grep("RANK", colnames(indivs))
  col_natl_rank		<- intersect(col_rank, col_natl)
  col_prac			<- grep("PRACTITIONER", colnames(indivs))
  col_prac_natl_rank 	<- intersect (col_natl_rank, col_prac)
  poid_col 			<- grep("HMS_POID", colnames(indivs))
  piid_col			<- grep("HMS_PIID", colnames(indivs))
  col_fac			<- grep("FAC", colnames(indivs))
  col_fac_natl_rank		<- intersect(col_natl_rank,col_fac)
  col_fac_rank		<- intersect(col_fac, col_rank)
  col_prac_fac_rank		<- intersect(col_fac_rank,col_prac)
  col_wl			<- grep("WORKLOAD", colnames(indivs))
  
  fixedranks <- (1:10)
  #convert rank table into data form
  pdf("INDIVS_TABLE_Check_dist_PIIDs_Phys_NATL_RANK.pdf",onefile=T)
  for (c in col_prac_natl_rank) {
    cat("\tColumn Name: ", colnames(indivs)[c],"\n")
    d <- unique(indivs[,c(piid_col,c)])
    ranked_dist <- table(d[,2])
    ranked_dist_df <- as.data.frame(ranked_dist)
    mer <- merge(fixedranks, ranked_dist_df, by.x=1, by.y=1, all.x=T)
    ex <- barplot(mer$Freq,main=sub("_PRACTITIONER_NATL_RANK", "", colnames(indivs)[c]),names.arg=mer$x)
    text(ex, mer$Freq+3, format(mer$Freq), xpd=TRUE, col="blue")
  }
  null_device<-dev.off()
  
  
  
  ##Check Distribution of POIDs by Facility National Rank per Decile
  #  Group By and Count each bucket.  The distribution should have fewest POIDs @ rank 10, increasing
  #  as the ranks decrease. If there are a few numbers out of order i.e. (10,9,8,6,7,5,4,2,3,1) Review
  #	the Min/Max Table and make sure counts line up. If the counts are low due to the nature of the buckets
  #	your pulling - okay to keep this way in deliverable
  
  #	Confirm that full decile distribution is achieved. If a few numbers are missing i.e. a 2 or 6 but all
  #	else is in line - okay to deliver - if due to the nature of the buckets you are pulling. If more than 2
  #	numbers are missing and a Quintile looks promising discuss with Sales and Dilip and perform a Quintile.
  #	If more than 5 numbers are missing and a trecile looks more promising discuss with Dilip/Sales and perform
  #	Trecile. 
  cat("\nCheck distribution of POID Facility National Rank in ORGS_TABLE_Check_dist_POIDs_Fac_NATL_RANK.pdf.\n")
  
  
  col_natl    	<- grep("NATL", colnames(orgs))
  col_rank 			<- grep("RANK", colnames(orgs))
  col_natl_rank		<- intersect(col_rank, col_natl)
  col_prac			<- grep("PRACTITIONER", colnames(orgs))
  col_prac_natl_rank 	<- intersect (col_natl_rank, col_prac)
  poid_col 			<- grep("HMS_POID", colnames(orgs))
  piid_col			<- grep("HMS_PIID", colnames(orgs))
  col_fac1			<- grep("FAC", colnames(orgs))
  col_fac2			<- grep("SUPPL", colnames(orgs))
  col_fac3      <- union(col_fac1,col_fac2)
  col_fac_natl_rank		<- intersect(col_natl_rank,col_fac3)
  col_fac_rank		<- intersect(col_fac3, col_rank)
  col_prac_fac_rank		<- intersect(col_fac_rank,col_prac)
  col_wl			<- grep("WORKLOAD", colnames(orgs))
  
  
  fixedranks <- (1:10)
  #convert rank table into data form
  pdf("ORGS_TABLE_Check_dist_POIDs_Fac_NATL_RANK.pdf",onefile=T)
  for (c in col_fac_natl_rank) {
    cat("\n\tColumn Name: ", colnames(orgs)[c],"\n")
    d <- unique(orgs[,c(poid_col,c)])
    ranked_dist <- table(d[,2])
    ranked_dist_df <- as.data.frame(ranked_dist)
    mer <- merge(fixedranks, ranked_dist_df, by.x=1, by.y=1, all.x=T)
    ex <- barplot(mer$Freq,main=sub("_FAC_NATL_RANK", "", colnames(orgs)[c]),names.arg=mer$x)
    text(ex, mer$Freq+3, format(mer$Freq), xpd=TRUE, col="blue")
    cat("\n")
  }
  
  
  null_device<-dev.off()
  
  sink()
  