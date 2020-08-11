#This script compares two files in the config folder: codeGroupMembers.tab (the new file) and 
#codesGroupMembers_OLD.tab (the old file). This helps us see what has changed between the two files
#and ensure that all changes were intentional.

#Read in files
old_cgm<-read.table("codeGroupMembers_OLD.tab", header=T, sep="\t", quote="",comment.char="", as.is=T, na.strings="")
new_cgm<-read.table("codeGroupMembers.tab", header=T, sep="\t", quote="",comment.char="", as.is=T, na.strings="")


sink("code_changes_summary.txt")

#If files are identical, stop.
#If files are different, look at what has changed.
if(identical(old_cgm,new_cgm)==TRUE){
cat("Old and new files are identical")  
}else{
  cat("Files are different. See below for a summary of changes.\n\n")
  #Tag each row to indicate which file it came from
  new_cgm$File<-"new_file"
  old_cgm$File<-"old_file"
  
  #Merge two files together
  merge_cgm<-merge(old_cgm,new_cgm,all.x=T,all.y=T)
  
  
  #Create column that concatenates values from columns 1-4
  #If a code is in multiple buckets, that shouldn't count as a duplicate
  merge_cgm$concat<-paste(merge_cgm$CODE_GROUP_NAME,merge_cgm$CODE,merge_cgm$CODE_GROUP_TYPE,merge_cgm$CODE_SCHEME,sep=",")
  
  
  #Set up function to identify duplicate values
  #Standard duplicated R function identifies first instance of value as unique 
  #and second instance as duplicated. Wanted a function that would identify
  #both instances of duplicated values as duplicates
  
  allDup <- function (value) { 
    duplicated(value) | duplicated(value, fromLast = TRUE) 
  } 
  

  #Add column indicating which codes are duplicated  
  merge_cgm$dupe<-allDup(merge_cgm$concat)

  #Grab the codes that are only in one file (i.e., the ones that have changed)  
  changes<-merge_cgm[merge_cgm$dupe==FALSE,]
  
  
  #Print which buckets have changes
  cat("The following buckets had code changes:\n")
  print(unique(changes$CODE_GROUP_NAME),quote=F)
 

  #Print which codes have changed
  cat("\n\nCodes removed (in old, not in new):\n\n")
  print(changes[changes$File=="old_file",1:4],row.names=F)
  
  
  cat("\n\nCodes added (in new, not in old):\n\n")
  print(changes[changes$File=="new_file",1:4],row.names = F)
  
}

sink()


