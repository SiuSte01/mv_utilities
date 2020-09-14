#Directory dates
dir_date <- "2018_01_31"

setwd('T:/Memorial_Hermann/')

#Locating the INA directories
ina_dir <- paste("T:/Memorial_Hermann/",dir_date,"_MH_PxDxs_and_INAs/",dir_date,"_INAs/, sep="")

#Automatically finding and listing miscellaneous delivery files 
misc_files <- c(list.files(payer_ar_dir, pattern="7z", recursive = T, full.names = T))
mf_zip_files <- c(list.files(mf_dir, pattern="zip", full.names = T))
mf_deliv_doc <- c(list.files(mf_dir, pattern="Delivery_Documentation", full.names = T))
mapping_file <- c(list.files(mapping_dir, pattern=".csv", full.names = T))

#Creating final list of misc files to copy
final_misc_files <- c(misc_files, mf_zip_files, mf_deliv_doc, mapping_file)

#Checking that all misc files are available
#ifelse (file.exists(final_misc_files)==FALSE){
#cat("\nmissing misc files:\n")}

#Locating delivery folder to copy misc files to
new_dir <- paste("T:/Tea_Leaves/", new_dir_date, "_Tea_Leaves_Emdeon_Delivery/7z_Files", sep="")

#Copy the files to output directory
file.copy(final_misc_files, new_dir)


source("Y:Statistics/Katie/Tea_Leaves/Delivery_File_Check/TL_Delivery_File_Check.R")
