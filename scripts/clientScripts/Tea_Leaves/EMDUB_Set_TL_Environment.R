
# #Directory for testing
# setwd("T:/Tea_Leaves/Testing/2019_10_01_TL_Environment_Test/2019_10_31_PxDx_and_INA")

#Determine date prefix to use
dir <- getwd()
dir_split <- unlist(strsplit(dir,split = "/"))
folder <- dir_split[length(dir_split)]
date_prefix <- substr(folder, 1,10)

#Create PxDx and INA folders
ina_folder <- paste0(date_prefix,"_INA_Emdeon")
pxdx_folder <- paste0(date_prefix,"_PxDx_Emdeon")

dir.create(ina_folder)
dir.create(pxdx_folder)

#Copy *_INA folders into INA folder
#Copy *_PxDx folders into PxDx folder
jobs <- list.dirs(path=".",recursive=F)
jobs_ina <- grep(jobs, pattern = "INA",value=T)
jobs_ina2 <- grep(jobs_ina,pattern="Emdeon",invert=T,value=T)
jobs_pxdx <- grep(jobs, pattern = "PxDx",value = T)
jobs_pxdx2 <- grep(jobs_pxdx,pattern="Emdeon",invert=T,value=T)

file.copy(jobs_ina2,ina_folder,recursive = T)
file.copy(jobs_pxdx2,pxdx_folder,recursive = T)

#Delete original folders after copy
for (i in 1:length(jobs_ina2)){
  unlink(jobs_ina2[i],recursive=T)
}

for (i in 1:length(jobs_pxdx2)){
  unlink(jobs_pxdx2[i],recursive=T)
}

#Update jobs to run dev EMD UB process (interim process until permanent EMD UB fix is in place)

#Set the CODE BASE in the settings.cfg: CODE_BASE = TL.
setwd(pxdx_folder)

for (i in 1:length(jobs_pxdx2)){
  setwd(jobs_pxdx2[i])
  tx  <- readLines("config/settings.cfg")
  tx2  <- gsub(pattern = "CODE_BASE = Prod_NewWH", replacement = "CODE_BASE = TL", x = tx)
  writeLines(tx2, con="config/settings.cfg")
  setwd("..")
}

#Set the FXFILES location in config/settings.cfg:  
#FXFILES = tl 
for (i in 1:length(jobs_pxdx2)){
  setwd(jobs_pxdx2[i])
  tx  <- readLines("config/settings.cfg")
  tx2  <- gsub(pattern = "FXFILES = ", replacement = "FXFILES = tl", x = tx)
  writeLines(tx2, con="config/settings.cfg")
  setwd("..")
}

#Copy EmdeonUBPOIDs.tab from prior month into each job (one level above config).

emd_ub_poids <- "/vol/cs/clientprojects/Tea_Leaves/TeaLeaves_Emdeon_Discussions/TL_EMD_UB_POID_List/EmdeonUBPOIDs.tab"

for (i in 1:length(jobs_pxdx2)){
  setwd(jobs_pxdx2[i])
  file.copy(emd_ub_poids,".",recursive = T)
  setwd("..")
}


