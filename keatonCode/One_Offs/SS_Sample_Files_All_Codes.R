#Inputs
date<-"2018_05_08"
allcodes_month_year<-"Mar2018"

#Find directories and files to copy
files_to_copy <- list.files("/vol/cs/clientprojects/Biltmore/AllCodes_RegionalFiles/All_Codes_Folder_Templates",full.names = T,include.dirs = F,recursive = T)
new_folder<-getwd()

#Create folder names
regions<-c("Heartland","Midwest","Northeast","Southeast","West")
folders_to_make<-paste0(date,"_SS_",regions)

#Create folder structure by looping through and copying files to appropriate folders
for (i in 1:length(folders_to_make)){
dir.create(paste(new_folder,folders_to_make[i],sep="/"))
regional_folder<-paste(new_folder,folders_to_make[i],sep="/")
setwd(regional_folder)
region_files_to_copy<-grep(regions[i],files_to_copy)
file.copy(files_to_copy[region_files_to_copy], regional_folder)
setwd("..")
}

#Find SS files in new folder
files_to_copy2<-list.files(new_folder,full.names=T,recursive=T,include.dirs = F)
files_to_copy3<-grep("SS",files_to_copy2,value = T)

#Replace date in idselectioninputs and filter_inputs_NEW with All Codes month and year
for( f in files_to_copy3 ){
  x <- readLines(f)
  y <- gsub("DATE_TO_REPLACE", allcodes_month_year, x )
  cat(y, file=f, sep="\n")
}

for (q in 1:length(folders_to_make)){
  regional_folder<-paste(new_folder,folders_to_make[q],sep="/")
  setwd(regional_folder)
  source("/vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/makeidlist.R")
  setwd("..")
}