#STEP 1
setwd("T:/Cabell_Huntington/2018_08_20_Refresh")


#Get date of folder
split1<-as.data.frame(strsplit("T:/Cabell_Huntington/2018_08_20_Refresh",split = "/"))
split2<-substr(split1[3,],1,10)

#Create delivery folder and subfolders
deliv_folder<-(paste0(".","/",split2,"_Delivery_Test"))
dir.create(deliv_folder)

main.dir<- setwd(deliv_folder)

#Create therapy line folders
folders<- c("Addiction_Dx","All_Codes","Cardio_Dx","Cardio_DxtoPx","GI_Px","Nephrology_Dx",
           "Neuro_Dx","Neuro_DxtoPx","ObGyn_Px","Oncology_Dx","Oncology_DxtoPx",
           "Ortho_Px","Pulmonology_Px","Radiology_Px","SportsMedicine_Px","Surgery_Px")

for (i in 1:length(folders)) {dir.create(paste(main.dir,folders[i], sep="/"))}

# Copy Filtered Splitter Files (NEEDS TESTING) 
--------------------------------------------------------------------------------------------------------------
#STEP2
#Trying to copy the files from the PxDxBucket/milestones folder to the corresponding delivery folder
#SINGLE BUCKET EXAMPLE

#PxDx part 2 filtered splitter files -> copy to delivery folder
part2<-paste("T:/Cabell_Huntington/2018_08_20_Refresh","PxDx_part_2",sep="/")
neurodxip_dir <- paste0(part2,"/Neuro_dx_IP","/milestones",sep="/")

# I CAN'T FIGURE OUT WHY I'M RECEIVING A 'CANNOT CHANGE WORKING DIRECTORY' ERROR
setwd(neurodxip_dir)
neuro_files <- list.files(neuroip.dir,pattern="HMS_")
file.copy(neuro_files,"T:/Cabell_Huntington/2018_08_20_Refresh/2018_08_20_Delivery/Neuro_Dx/IP" , recursive = F )


--------------------------------------------------------------------------------------------------------------
#MY HOPE IS TO MAKE STEP 2 LOOP THROUGH ALL IP SERVICE LINES AND RENAME ALL IP FILES WITH A SUFFIX '_IP'"
  
--------------------------------------------------------------------------------------------------------------
#DO THE SAME STEPS FOR OP PXDX FILES
  
--------------------------------------------------------------------------------------------------------------
#COPY OVER THE NEXTWORK FILES TO THE DELIVERY FOLDERS
