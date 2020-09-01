# Run from new main project PxDx folder
# Manually change old_dir path
# R CMD BATCH --vanilla /vol/datadev/Statistics/Katie/Tea_Leaves/Monthly_Compare_Codes_Files.R
# Compares the codes files with a bucket vs previous month (Projections must be complete)

old_dir<-"/vol/cs/clientprojects/Tea_Leaves/2017_04_28_PxDx_and_INA/2017_04_28_PxDx_Emdeon"
new_dir<-getwd()

#Find paths for every codes/codes.tab file
old_codes<-list.files(path=Sys.glob(paste0(old_dir,"/*/*/codes")),pattern="codes.tab",recursive=F,full.names=T) 
new_codes<-list.files(path=Sys.glob(paste0(new_dir,"/*/*/codes")),pattern="codes.tab",recursive=F,full.names=T) 

#Replace dates in file paths so you can compare bucket names
old_codes_gsub<-gsub("20.*PxDx_Emdeon","20YY_MM_DD_PxDx_and_INA/20YY_MM_DD_PxDx_Emdeon",old_codes)
new_codes_gsub<-gsub("20.*PxDx_Emdeon","20YY_MM_DD_PxDx_and_INA/20YY_MM_DD_PxDx_Emdeon",new_codes)

print(new_dir)
print(old_dir)

sink("code_file_comparisons.txt")

#Which buckets were added or removed?

if(identical(old_codes_gsub,new_codes_gsub)=="FALSE"){
cat("The following buckets will not be checked:\n")
cat("\nIn old, not in new\n")
print(gsub("/vol/cs/clientprojects/Tea_Leaves/20YY_MM_DD_PxDx_and_INA/20YY_MM_DD_PxDx_Emdeon/","",setdiff(old_codes_gsub,new_codes_gsub)))


cat("\nIn new, not in old\n")
print(gsub("/vol/cs/clientprojects/Tea_Leaves/20YY_MM_DD_PxDx_and_INA/20YY_MM_DD_PxDx_Emdeon/","",setdiff(new_codes_gsub,old_codes_gsub)))
}

#Keep buckets in both old and new dirs
buckets_both<-intersect(old_codes_gsub,new_codes_gsub)

#Split out path names to get bucket and sub-bucket names
buckets_both_split<-strsplit(buckets_both,split="/")
buckets_both_mat<-matrix(unlist(buckets_both_split), ncol=11, byrow=TRUE)
buckets_both_df<-as.data.frame(buckets_both_mat)

#Grab bucket and sub-bucket name for buckets in both old and new dirs
buckets_both_df$bucket_sub<-paste(buckets_both_df$V8,buckets_both_df$V9,sep="/")

buckets_both_final<-buckets_both_df$bucket_sub



#Search for bucket name in each dir and compare
for (i in 1:length(buckets_both_final)){
  bucket_to_find<-buckets_both_final[i]
  old_codes_dir<-old_codes[grep(bucket_to_find,old_codes)]
  old_code_list<-read.table(old_codes_dir, header=F, sep="\t", quote="", comment.char="", as.is=T, na.strings="")
  
  new_codes_dir<-new_codes[grep(bucket_to_find,new_codes)]
  new_code_list<-read.table(new_codes_dir, header=F, sep="\t", quote="", comment.char="", as.is=T, na.strings="")
  
  #Print differences

  if(identical(old_code_list,new_code_list)=="FALSE"){
    cat("\nCodes changes detected:\n")
    print(bucket_to_find,quote=F)
    cat("\nDeleted codes:\n")
    print(setdiff(old_code_list$V1,new_code_list$V1),quote=F)
    cat("\nAdded codes:\n")
    print(setdiff(new_code_list$V1,old_code_list$V1),quote=F)
    cat("\n\n")
  }
    
}

sink()
