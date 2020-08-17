#Directory dates
old_dir_date <- '2020_06_30'
new_dir_date <- '2020_07_31'

setwd('T:/Tea_Leaves/')

#Locating Zip3 PayerMix,,MasterFile
mf_dir <- paste("T:/Tea_Leaves/",new_dir_date,"_PxDx_and_INA/Masterfile/Delivery", sep="")
# boardcert_dir <- paste("T:/Tea_Leaves/MasterFile/quarterly_masterfile/",mf_date,"/Board_Certs", sep="")
payer_ar_dir <- paste("T:/Tea_Leaves/",new_dir_date,"_PxDx_and_INA", sep="")
mapping_dir <- paste("T:/Tea_Leaves/TeaLeaves_Emdeon_Discussions", sep="")

#Added 8/27/19 to copy Updated Specialties file if found
spec_dir <- paste("T:/Tea_Leaves/",new_dir_date,"_PxDx_and_I?NA/Masterfile/Updated_PIID_Specialty_File", sep="")

#Automatically finding and listing miscellaneous delivery files 
misc_files <- c(list.files(payer_ar_dir, pattern="7z", recursive = T, full.names = T))
mf_zip_files <- c(list.files(mf_dir, pattern="zip", full.names = T))
mf_deliv_doc <- c(list.files(mf_dir, pattern="Delivery_Documentation", full.names = T))
mapping_file <- c(list.files(mapping_dir, pattern=".csv", full.names = T))
boardcert_file <- c(list.files(mf_dir, pattern="HMS_Board_Certifications", full.names = T))

#Added 8/27/19 to copy Updated Specialties file if found
spec_file <- c(list.files(spec_dir, pattern="Updated_PIID_Specialties", full.names = T))

#Creating final list of misc files to copy
final_misc_files <- c(misc_files, mf_zip_files, mf_deliv_doc, mapping_file, boardcert_file,spec_file)

#Checking that all misc files are available
#ifelse (file.exists(final_misc_files)==FALSE){
#cat("\nmissing misc files:\n")}

#Locating delivery folder to copy misc files to
new_dir <- paste("T:/Tea_Leaves/", new_dir_date, "_Tea_Leaves_Emdeon_Delivery/7z_Files", sep="")

#Copy the files to output directory
file.copy(final_misc_files, new_dir)


source("Y:/Statistics/Katie/Tea_Leaves/Delivery_File_Check/TL_Delivery_File_Check.R")
