######For QAing Tea Leaves, template for QA of other repeating projects
# test if there is at least one argument: if not, return an error

args = commandArgs(trailingOnly=TRUE)

if (length(args) < 4) {
  stop("Required args: New_month_dir Old_month_dir Out_file Prefix", call.=FALSE)
}

New_month_dir=args[1]
Old_month_dir=args[2]
Out_file=args[3]
Prefix=args[4]

print("Running with args:")
print(paste(New_month_dir,Old_month_dir,Out_file,Prefix))

library(stringr)

####testing####
#New_month_dir="/vol/cs/clientprojects/Tea_Leaves/2016_03_31_PxDx_and_INA/2016_03_31_INA_Emdeon"
#Old_month_dir="/vol/cs/clientprojects/Tea_Leaves/2016_02_29_PxDx_and_INA/2016_02_29_INA_Emdeon"
#Out_file="/vol/cs/clientprojects/Tea_Leaves/QA_outfiles/test2.csv"
#Prefix="Mar_Feb2"

is_new=0

if (! file.exists(Out_file)){
  print("Output file not found. If this is not a new project, please check the path")
  is_new=1
} else {
  orig<-read.csv(Out_file,stringsAsFactors=FALSE)
  if(any(grepl(paste(Prefix,"difference",sep="_"),colnames(orig)))){
    stop("Prefix already found. Make sure this hasn't been run.",call.=FALSE)
  }
}

##look for files present in all folders. TESTING - what happens if these aren't found? Maybe need if/then logic for all
print("Getting counts for new month.")
all_inanat_new<-system(paste("wc -l ",New_month_dir,"/*/*/Comb/*fordelivery.txt | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
all_tabs_new<-system(paste("wc -l ",New_month_dir,"/*/*/Comb/Filter/*.tab | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
all_network_new<-system(paste("wc -l ",New_month_dir,"/*/*/Comb/Filter/network.txt | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
all_profiles_new<-system(paste("wc -l ",New_month_dir,"/*/*/Comb/Filter/network_indiv_profiles.txt | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
all_actrep_new<-system(paste("wc -l ",New_month_dir,"*/*/activityreport_nodesc* | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)

#build list of all files that must be present
new_all<-c(all_tabs_new, all_network_new, all_profiles_new, all_actrep_new, all_inanat_new)

#check for payermix files that may or may not exist
test<-suppressWarnings(system(paste("ls ",New_month_dir,"/*/payermix.txt",sep=""),intern=T,ignore.stderr=T))
if(is.null(attr(test,"status"))){
  all_payermix_new<-system(paste("wc -l ",New_month_dir,"/*/payermix.txt | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
  new_all<-c(new_all,all_payermix_new)
}else{
  print("No payermix detected")
}

#check for zip3 files that may or may not exist
test<-suppressWarnings(system(paste("ls ",New_month_dir,"/TeaLeaves_Zip3.txt",sep=""),intern=T,ignore.stderr=T))
if(is.null(attr(test,"status"))){
  all_zip3_new<-system(paste("wc -l ",New_month_dir,"/TeaLeaves_Zip3.txt | sed s@'",New_month_dir,"'@''@g",sep=""),intern=T)
  new_all<-c(new_all,all_zip3_new)
}else{
  print("No zip3 detected")
}

###clean up data
new_all<-str_trim(new_all)
new_all<-as.data.frame(str_split_fixed(new_all," ",2))
new_all$V1<-as.numeric(as.character(new_all$V1))
new_all<-new_all[which(as.character(new_all$V2) != "total"),]

###get info for old month
print("Getting counts for old month.")
all_inanat_old<-system(paste("wc -l ",Old_month_dir,"/*/*/Comb/*fordelivery.txt | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
all_tabs_old<-system(paste("wc -l ",Old_month_dir,"/*/*/Comb/Filter/*.tab | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
all_network_old<-system(paste("wc -l ",Old_month_dir,"/*/*/Comb/Filter/network.txt | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
all_profiles_old<-system(paste("wc -l ",Old_month_dir,"/*/*/Comb/Filter/network_indiv_profiles.txt | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
all_actrep_old<-system(paste("wc -l ",Old_month_dir,"*/*/activityreport_nodesc* | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
old_all<-c(all_tabs_old, all_network_old, all_profiles_old, all_actrep_old, all_inanat_old)

#check for payermix files that may or may not exist
test<-suppressWarnings(system(paste("ls ",Old_month_dir,"/*/payermix.txt",sep=""),intern=T,ignore.stderr=T))
if(is.null(attr(test,"status"))){
  all_payermix_old<-system(paste("wc -l ",Old_month_dir,"/*/payermix.txt | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
  old_all<-c(old_all,all_payermix_old)
}

#check for zip3 files that may or may not exist
test<-suppressWarnings(system(paste("ls ",Old_month_dir,"/TeaLeaves_Zip3.txt",sep=""),intern=T,ignore.stderr=T))
if(is.null(attr(test,"status"))){
  all_zip3_old<-system(paste("wc -l ",Old_month_dir,"/TeaLeaves_Zip3.txt | sed s@'",Old_month_dir,"'@''@g",sep=""),intern=T)
  old_all<-c(old_all,all_zip3_old)
}

#clean up old data
old_all<-str_trim(old_all)
old_all<-as.data.frame(str_split_fixed(old_all," ",2))
old_all$V1<-as.numeric(as.character(old_all$V1))
old_all<-old_all[which(as.character(old_all$V2) != "total"),]

#check for mismatch in files found!
print("Checking for differences.")
missing_from_old<-new_all$V2[which(! new_all$V2 %in% old_all$V2)]
missing_from_new<-old_all$V2[which(! old_all$V2 %in% new_all$V2)]

#check percent change
new_all$old_values<-old_all$V1[match(new_all$V2,old_all$V2)]
new_all$difference<-new_all$V1-new_all$old_values
new_all$percent<-new_all$difference/new_all$old_values*100

warn_percents<-new_all[which(abs(new_all$percent) > 5),]

print("missing from new:")
print(missing_from_new)
print("missing from old:")
print(missing_from_old)
print("Percent change > 5%")
print(warn_percents)

new_all$new_dir<-New_month_dir
new_all$old_dir<-Old_month_dir
new_all$notes<-""
new_all<-new_all[,c(2,1,3:ncol(new_all))]
colnames(new_all)[1:2]<-c("file_path","new_values")
colnames(new_all)<-paste(Prefix,colnames(new_all),sep="_")
colnames(new_all)[1]<-"file_path"

#update file

if (is_new == 1){
write.csv(new_all,Out_file,row.names=F)
}else{

out<-merge(orig,new_all,by="file_path",sort=T,all=T)
write.csv(out,Out_file,row.names=F)
}

