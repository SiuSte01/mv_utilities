#####FOR TESTING PURPOSES
#setwd("T:/Tea_Leaves/MasterFile/quarterly_masterfile/2017-08-31/qa")

dir<-getwd()
setwd(dir)

#Import R_inputs.txt file
if(!file.exists("R_inputs_QA.txt")){
  cat("WARNING: R_inputs_QA.txt file not found! Exiting.")
}

par<-read.table("R_inputs_QA.txt",header=T,sep="\t",as.is=T,fill=T)
olddate<-subset(par,Parameter=="olddate")$Value
newdate<-subset(par,Parameter=="newdate")$Value

olddir<-paste0("/vol/cs/clientprojects/Tea_Leaves/MasterFile/quarterly_masterfile/",olddate,"/qa")
newdir<-paste0("/vol/cs/clientprojects/Tea_Leaves/MasterFile/quarterly_masterfile/",newdate,"/qa")

#Copy over inputs file and qareport file from old directory
files_olddir<-list.files(olddir,full.names=T)
files_to_copy<-files_olddir[grep("inputs.txt|qareport.txt",files_olddir)]
file.copy(files_to_copy,newdir)
file.rename("qareport.txt","old_qareport.txt")

#Find and replace old date with new date in copied inputs file
x <- readLines("inputs.txt")
y <- gsub(olddate, newdate, x )
cat(y, file="inputs.txt", sep="\n")


#Run standard MF QA script
arg1 <- "nohup"
arg2 <- "inputs.txt"
arg3 <- "2>"
arg4 <- "Stderr"
arg5 <- "&"
cmd <- paste(arg1, "perl", "/vol/datadev/Statistics/Dilip/MiscProjects/DeltaMFQA/deltamfqa.pl", arg2, arg3, arg4, arg5)
system(cmd)

#Wait 10 minutes for QA script to run before moving on to next step
Sys.sleep(600)

#Remove % signs from new qareport.txt file
x <- readLines("qareport.txt")
y <- gsub("%", "", x )
cat(y, file="qareport_no_pcts.txt", sep="\n")

x <- readLines("old_qareport.txt")
y <- gsub("%", "", x )
cat(y, file="old_qareport.txt", sep="\n")

#Import qareport files
qareport_new<-read.table("qareport_no_pcts.txt",header=F, stringsAsFactors = F)
qareport_old<-read.table("old_qareport.txt",header=F, stringsAsFactors = F)

#Merge old and new qareport files into one file
qareport_new$concat<-paste(qareport_new$V1,qareport_new$V2)
qareport_old$concat<-paste(qareport_old$V1,qareport_old$V2)
qareport_merged<-unique(merge(qareport_old, qareport_new, by="concat"))
qareport_merged<-qareport_merged[,c("concat","V3.x","V3.y")]
names(qareport_merged)<-c("Parameter","Old","New")

#Turn off scientific notation
options(scipen=999)
#Calculate difference and pct change between old and new files
qareport_merged$Diff<-qareport_merged$New - qareport_merged$Old
qareport_merged$Pct_Change<-(qareport_merged$Diff/qareport_merged$Old)*100
qareport_merged$Pct_Change<-round(qareport_merged$Pct_Change,2)
qareport_merged$New<-round(qareport_merged$New,2)
qareport_merged$Old<-round(qareport_merged$Old,2)
qareport_merged$Diff<-round(qareport_merged$Diff,2)

# Print QA summary results ------------------------------------------------

#Create output file to summarize results
sink("qa_summary_report.txt")

cat("Old directory: ",olddir,"\n")
cat("New directory: ",newdir,"\n\n")

#Print any rows with churn >= 3% or <= -3%
cat("Rows with more than 3% or less than -3% churn:\n\n")
qareport_churn<-qareport_merged[which(qareport_merged$Pct_Change>=3 |qareport_merged$Pct_Change<=-3),]
print(qareport_churn[order(qareport_churn[,5]),],row.names=FALSE)
cat("\n")

#Check that number of columns has not changed since last delivery
num_cols<-qareport_merged[grep("NumberOfColumns",qareport_merged$Parameter),]
num_cols_diff<-num_cols[which(num_cols$Diff != 0),]

if(nrow(num_cols_diff)>0){
  cat("FAILED: Number of columns has changed in at least one table.\n\n")
  print(num_cols[which(num_cols$Diff != 0),],row.names = F)
}else{
  cat("Passed: All tables have same number of columns as previous delivery.\n\n")
}

#Check for non-unique IDs
non_unique_cols<-qareport_merged[grep("NumberOfNonUniqueIDs",qareport_merged$Parameter),]
non_unique_diff<-non_unique_cols[which(non_unique_cols$New != 0),]

if(nrow(non_unique_diff)>0){
  cat("FAILED: Non-unique IDs exist in at least one table.\n\n")
  print(non_unique_diff[which(non_unique_diff$New != 0),],row.names = F)
}else{
  cat("Passed: Zero non-unique IDs found.\n\n")
}

# #Practitioner type check
# prac_type<-read.table("ValuesFor_PRACTITIONER_TYPE_In_HMS_Individual_Profiles.tab",header=F, stringsAsFactors = F, sep="\t")
# prac_type_expected<-c("Physician","Advanced Practice Nurse","Physician Assistant","Chiropractor","Podiatrist","Optometrist","Dentist")
# 
# if(identical(sort(prac_type_expected),sort(prac_type[,1]))=="TRUE"){
#   cat("Passed: All expected practitioner types are included.\n\n")
# }else{
#   cat("FAILED: Practitioner type values differ from expected values.\n\n")
#   cat("\tPractitioner types included in MasterFile that were not expected:\n\t")
#   print(setdiff(prac_type_expected,prac_type[,1]))
#   cat("\n\tExpected practitioner types not found in MasterFile:\n\t")
#   print(setdiff(prac_type[,1],prac_type_expected))
# }


sink()

sink("qa_report_all.tab")
print(qareport_merged)
sink()

