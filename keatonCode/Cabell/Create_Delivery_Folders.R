#Run in Linux, not in R Studio


# Create Delivery Folder and Subfolders -----------------------------------
# setwd("T:/Cabell_Huntington/2018_07_25_Refresh")

proj_folder<-getwd()

#Get date of folder
split1<-as.data.frame(strsplit(proj_folder,split = "/"))
split2<-substr(split1[6,],1,10)

#Create delivery folder and subfolders
deliv_folder<-(paste0(proj_folder,"/",split2,"_Delivery_TEST"))

dir.create(deliv_folder)

setwd(deliv_folder)

folders<-c("Addiction_Dx","All_Codes","Cardio_Dx","Cardio_DxtoPx","GI_Px","Nephrology_Dx",
           "Neuro_Dx","Neuro_DxtoPx","ObGyn_Px","Oncology_Dx","Oncology_DxtoPx",
           "Ortho_Px","Pulmonology_Px","Radiology_Px","SportsMedicine_Px","Surgery_Px")

for (i in 1:length(folders))  { 
  dir.create(paste(deliv_folder,folders[i], sep="/")) 
  setwd(paste(deliv_folder,folders[i], sep="/"))
  dir.create("IP")
  dir.create("OP")
  setwd("..") 
} 







# Copy Filtered Splitter Files (NEEDS TESTING) ----------------------------

# # PxDx part 1 filtered splitter files, copy to delivery folder
# part1<-paste(proj_folder,"PxDx_part_1",sep="/")
# part1_folders<-list.dirs(part1,full.names = F,recursive=F)
# i_part1<-grep("x_",part1_folders,value=T)


#Find all PxDx_Part folders
pxdx_parts<-grep("PxDx_part",list.dirs(getwd(),full.names=T,recursive=F),value=T)

milestone_paths<-data.frame(Path=character(),stringsAsFactors=FALSE)

#Find all relevant milestones folders
for (i in 1:length(pxdx_parts))  {
  milestones<-grep("milestones",list.dirs(pxdx_parts[i],full.names=T,recursive=T),value=T) 
  setwd(milestones)
  milestone_paths<-rbind(milestone_paths,as.data.frame(milestones))
  ##Get rid of project level combined milestones folders
  ipop<-c("IP","OP")
  milestone_paths2 <- unique(grep(paste(ipop,collapse="|"), milestone_paths$milestones, value=TRUE))
}

#Print lists of milestones folders used
cat("Milestones folders found:\n")
print(milestone_paths2)





#Use mapping file. WRAP THIS ALL IN A LOOP.

mapping_file<-read.table("Y:/Statistics/Katie/Cabell/Testing/mapping.txt",header=T,sep="\t")
  
#Find line with mapping file value
i<-1
milestones_i<-grep(mapping_file[i,1],milestone_paths2,value=T)

#Create string to be replaced in file path
milestones_replace<-paste(mapping_file[i,1],"milestones",sep="/")
gsub(milestones_replace,mapping_file[i,2],milestone_paths2)

files_to_copy<-c("HMS_Individuals.tab","HMS_Organizations.tab","HMS_PxDx.tab")

