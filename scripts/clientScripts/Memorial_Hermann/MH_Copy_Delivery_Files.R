#Directory dates
dir_date <- "2018_01_31"
deliv_date <- "2018_02_16"

setwd('T:/Memorial_Hermann/')

#Locating the INA directory
ina_dir <- paste("T:/Memorial_Hermann/",dir_date,"_MH_PxDxs_and_INAs/",dir_date,"_INAs", sep="")

#Finding and listing the *filtered.tab and network files from each INA
dx_filtered_files <- c(list.files(ina_dir, pattern="grp1_filtered.tab", recursive = T, full.names = T))
px_filtered_files <- c(list.files(ina_dir, pattern="grp2_filtered.tab", recursive = T, full.names = T))
network_files <- c(list.files(ina_dir, pattern="network_full.txt", recursive = T, full.names = T))

#Creating final list of files to copy
list_filestocopy <- c(dx_filtered_files, px_filtered_files, network_files)

#Producing delivery directories in delivery folder
source("Y:Statistics/Galerie/Memorial_Hermann/Creating_MH_delivery_folders.R")
-----------------------------------------------------------------------------------------------------------------
#Locating delivery folder to copy misc files to
new_dir <- paste("T:/Tea_Leaves/", dir_date, "_MH_Delivery/Flat_Files_Work", sep="")

#Copy the files to output directory
file.copy(final_misc_files, new_dir)



