
#To manually put in the file paths
#old_dir_path <- ("T:/Tea_Leaves/2018_08_31_Tea_Leaves_Emdeon_Delivery/7z_Files")
#new_dir_path <- ("T:/Tea_Leaves/2018_09_28_Tea_Leaves_Emdeon_Delivery/7z_Files")

#To use standard file paths based on date
old_dir_path<-paste0("/vol/cs/clientprojects/Tea_Leaves/",old_dir_date,"_Tea_Leaves_Emdeon_Delivery/7z_Files")
new_dir_path<-paste0("/vol/cs/clientprojects/Tea_Leaves/",new_dir_date,"_Tea_Leaves_Emdeon_Delivery/7z_Files")

#Find zip files in folders (.zip or .7z)
old_zip_names <- list.files(old_dir_path,pattern="z")
new_zip_names <- list.files(new_dir_path,pattern="z")

#Add in MF Delivery Document file name
old_mf_deliverydoc <-list.files(old_dir_path,pattern="Delivery_Documentation")
new_mf_deliverydoc <- list.files(new_dir_path,pattern="Delivery_Documentation")

old_zip_names <- union(old_zip_names,old_mf_deliverydoc)
new_zip_names <- union(new_zip_names,new_mf_deliverydoc)

###Addition on 7/30/18: Add in Board Cert file
old_bc <-list.files(old_dir_path,pattern="Board_Certification")
new_bc <- list.files(new_dir_path,pattern="Board_Certification")

old_zip_names <- union(old_zip_names,old_bc)
new_zip_names <- union(new_zip_names,new_bc)


###Addition in Sept 2019: Add in Updated Specialties file
old_spec <-list.files(old_dir_path,pattern="Updated_PIID_Specialties")
new_spec <-list.files(new_dir_path,pattern="Updated_PIID_Specialties")

old_zip_names <- union(old_zip_names,old_spec)
new_zip_names <- union(new_zip_names,new_spec)


#Parse out month from folder date and drop leading zero
old_month <- as.integer(substr(old_dir_date,6,7))
new_month <- as.integer(substr(new_dir_date,6,7))

old_year <- unlist(strsplit(old_dir_date,"_"))[1]
new_year <- unlist(strsplit(new_dir_date,"_"))[1]

#Convert month number to month name (since file names contain month name)
old_month_name <- month.name[old_month]
new_month_name <- month.name[new_month]

#Add in TL_Month_Service_Mapping.csv file
#This was added for April 2017 delivery at client's request
old_mapping<-list.files(old_dir_path,pattern="Service_Line_Mapping")
new_mapping<-list.files(new_dir_path,pattern="Service_Line_Mapping")

old_mapping2 <- sub(paste0("TL_",old_month_name),replacement="TL",old_mapping,fixed=F)
new_mapping2 <- sub(paste0("TL_",new_month_name),replacement="TL",new_mapping,fixed=F)

# old_zip_names <- union(old_zip_names,old_mapping2)
# new_zip_names <- union(new_zip_names,new_mapping2)


#Replace month and date in file names so they can be compared
old_date_filename <- paste(old_year,"_",old_month_name,"_", sep="")
new_date_filename <- paste(new_year,"_",new_month_name,"_", sep="")

old_zip_names2 <- sub(old_date_filename,replacement="",old_zip_names,fixed=F)
new_zip_names2 <- sub(new_date_filename,replacement="",new_zip_names,fixed=F)

old_zip_names3<-sub(old_dir_date,replacement="",old_zip_names2,fixed=F)
new_zip_names3<-sub(new_dir_date,replacement="",new_zip_names2,fixed=F)


#######Addition by Katie on 3/7/18: Compare file names of delivery files to names in csv mapping file
new_mapping_path<-list.files(new_dir_path,pattern="Service_Line_Mapping",full.names = T)
mapping_csv<-read.csv(new_mapping_path,header = T,fill=T,na.strings="")


csv_names<-c(as.character(mapping_csv[,6]),as.character(mapping_csv[,7]),as.character(mapping_csv[,8]))
csv_names_no_na<-(csv_names[!is.na(csv_names)])

#Remove service line mapping file from comparison (as that won't be listed in the mapping file itself)
new_zip_names_csv_comp<-new_zip_names3[!grepl("TL_Service_Line_Mapping",new_zip_names)]

csv_names_no_date<-sub("201X_MONTH_",replacement="",csv_names_no_na,fixed=F)
csv_names_no_date2<-sub("201X_XX_XX",replacement="",csv_names_no_date,fixed=F)


monthly_folder_path<-paste0("/vol/cs/clientprojects/Tea_Leaves/",new_dir_date,"_PxDx_and_INA")
setwd(monthly_folder_path)

###Addition/change: Print summary of comparison results
sink("comparison_summary.txt")

cat("Are csv mapping file and delivery files an exact match?\t")
cat(identical(sort(new_zip_names_csv_comp),sort(csv_names_no_date2)))

if(identical(sort(new_zip_names_csv_comp),sort(csv_names_no_date2))==FALSE){
  cat("\n\n\tIn csv, not in delivery files:\n")
  print(setdiff(csv_names_no_date2,new_zip_names_csv_comp))
  cat("\n\tIn delivery files, not in csv:\n")
  print(setdiff(new_zip_names_csv_comp,csv_names_no_date2))
}

cat("\n\nAre current month's delivery files and last month's delivery files an exact match?\t")

cat(identical(old_zip_names3,new_zip_names3))

if(identical(sort(old_zip_names3),sort(new_zip_names3))==FALSE){
  cat("\n\n\tIn old, not in new:\n")
  print(setdiff(old_zip_names3,new_zip_names3))
  cat("\n\tIn new, not in old:\n")
  print(setdiff(new_zip_names3,old_zip_names3))
}

cat("\n\nComparison of csv mapping file names")
cat("\n\tLast month's mapping file name:",old_mapping2)
cat("\n\tCurrent month's mapping file name:",new_mapping2)

#KE Added 6/27/18
#Check that all INA and PxDx zip file names start with year and month prefix
pxdx_ina_names<-c("_INA","_PxDx")
matches <- grep(paste(pxdx_ina_names,collapse="|"), new_zip_names, value=TRUE)
no_date_files<-grep(new_date_filename,matches,invert=T, value=T)
if(length(no_date_files>0)){
  cat("WARNING: These files do not have the expected YYYY_MM prefix in their name:",no_date_files)
}


sink()
file.show("comparison_summary.txt")
