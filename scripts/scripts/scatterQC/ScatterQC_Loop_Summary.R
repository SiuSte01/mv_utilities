# Updated 4/8/19 to create two versions of script.
# (1) Standard version: If folder path does NOT contain "Grifols," expects you have multiple jobs AND
# uses thresholds to show only the buckets with the most churn.
# (2) Grifols version: If folder path contains "Grifols," runs this version. Expects you have one job
# AND does not use thresholds (instead prints results for every single bucket)

#Run from main project PxDx folder (e.g., T:/Tea_Leaves/YYYY_MM_DD_PxDx_and_INA/YYYY_MM_DD_PxDx_Emdeon)

# Updated June 2019 to create a third version for HealthGrades
# Expects different HG-specific folder structure (more levels). Run from ncileGroups folder.
# Different thresholds. Includes buckets in output if percent good < 80% or if row change > 20%.
# Added note at bottom of output file that specifics which version of the script was run.

options(scipen = 999,digits=4)

# Check which version of script to run (standard, Grifols, or HG) -----------------------------------------------
dir<-getwd()
grifols_dir<-grepl("Grifols",dir)
hg_dir<-grepl("HealthGrades",dir)

# Find scatterqc_output file paths ----------------------------------------

#Recursive search for all scatterqc_output files
if(hg_dir==1){
  #If in HG directory, expect HG folder structure
  matches.scatter<-list.files(path=Sys.glob("*/*/*/*/QA"),pattern="scatterqc_output.txt",recursive=F,full.names=T) 
}else if(grifols_dir==1){
  #If in Grifols directory, expect Grifols folder structure (only one job)
  matches.scatter<-list.files(path=Sys.glob("*/QA"),pattern="scatterqc_output.txt",recursive=F,full.names=T) 
}else{
  #Otherwise, run standard version (expects multiple jobs)
  matches.scatter<-list.files(path=Sys.glob("*/*/QA"),pattern="scatterqc_output.txt",recursive=F,full.names=T) 
}

#Set up empty data objects to store data
per_good_indiv<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
per_good_org<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
per_good_pxdx<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
indiv_row_change<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
org_row_change<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
pxdx_row_change<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)

# Percent Good: Indivs ----------------------------------------------------

#For each bucket's Indiv, loop through and pull Percent Good
for (i in 1:length(matches.scatter)){
  scatter_output <- read.delim(matches.scatter[i],header=F,sep="\t",as.is=T,row.names=NULL,stringsAsFactors = FALSE)
  
  #Find "Total % good" rows in scatterqc_output.txt files for Indivs table
  good_indiv <- scatter_output[7,2]
  good_indiv <- cbind(matches.scatter[i], good_indiv)
  colnames(good_indiv) <- c("Bucket","Percent_Good_Indiv")
  
  #Create table with all "Total % Good" values for Indivs table
  per_good_indiv <- rbind(per_good_indiv,as.data.frame(good_indiv))

  #Find % change in row count in scatterqc_output.txt files for Indivs table
  indiv_row_per <- scatter_output[3,5]
  indiv_row_per <- cbind(matches.scatter[i], indiv_row_per)
  colnames(indiv_row_per) <- c("Bucket","Percent_Change")
  
  #Create table with all % change in row count values for Indivs table
  indiv_row_change <- rbind(indiv_row_change,as.data.frame(indiv_row_per))

}


# Indivs: Find Problematic Buckets ---------------------------------------

#Remove unnecessary text  
per_good_indiv2 <- as.data.frame(sapply(per_good_indiv,gsub,pattern="Total percent good = ",replacement=""))
per_good_indiv3 <- as.data.frame(sapply(per_good_indiv2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
indiv_row_change2 <- as.data.frame(sapply(indiv_row_change,gsub,pattern="%",replacement=""))
indiv_row_change3 <- as.data.frame(sapply(indiv_row_change2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
#Extra step to shorten Tea Leaves names
per_good_indiv4 <- as.data.frame(sapply(per_good_indiv3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))
indiv_row_change4 <- as.data.frame(sapply(indiv_row_change3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))

#Print buckets with change above/below threshold
if(hg_dir==1){
  #Run HealthGrades version
  #Convert percent to numeric and select rows where percent good is less than 80%
  per_good_indiv4$Percent_Good_Indiv <- as.numeric(as.character(per_good_indiv4$Percent_Good_Indiv))
  low_pg_indiv <- per_good_indiv4[which(per_good_indiv4$Percent_Good_Indiv < 80),]
  
  #Convert percent to numeric and select rows where abs value of row count change is > 20%
  indiv_row_change4$Percent_Change <- as.numeric(as.character(indiv_row_change4$Percent_Change))
  high_indiv_change <- indiv_row_change4[which(abs(indiv_row_change4$Percent_Change) > 20),]
}else if(grifols_dir==1){
  #Run Grifols version
  #Convert percent to numeric and select all rows
  per_good_indiv4$Percent_Good_Indiv <- as.numeric(as.character(per_good_indiv4$Percent_Good_Indiv))
  low_pg_indiv <- per_good_indiv4

  #Convert percent to numeric and select all rows
  indiv_row_change4$Percent_Change <- as.numeric(as.character(indiv_row_change4$Percent_Change))
  high_indiv_change <- indiv_row_change4
}else{
  #Run standard version
  #Convert percent to numeric and select rows where percent good is less than 95%
  per_good_indiv4$Percent_Good_Indiv <- as.numeric(as.character(per_good_indiv4$Percent_Good_Indiv))
  low_pg_indiv <- per_good_indiv4[which(per_good_indiv4$Percent_Good_Indiv < 95),]
  
  #Convert percent to numeric and select rows where abs value of row count change is > 3%
  indiv_row_change4$Percent_Change <- as.numeric(as.character(indiv_row_change4$Percent_Change))
  high_indiv_change <- indiv_row_change4[which(abs(indiv_row_change4$Percent_Change) > 3),]
}

# Percent Good: Orgs ----------------------------------------------------

#For each bucket's Orgs, loop through and pull Percent Good

for (i in 1:length(matches.scatter)){
  scatter_output <- read.delim(matches.scatter[i],header=F,sep="\t",as.is=T,row.names=NULL,stringsAsFactors = FALSE)

  #Find "Total % good" rows in scatterqc_output.txt files for Indivs table
  good_org <- scatter_output[14,2]
  good_org <- cbind(matches.scatter[i], good_org)
  colnames(good_org) <- c("Bucket","Percent_Good_Org")
  
  #Create table with all "Total % Good" values for Orgs table
  per_good_org <- rbind(per_good_org,as.data.frame(good_org))
  
  #Find % change in row count in scatterqc_output.txt files for Orgs table
  org_row_per <- scatter_output[4,7]
  org_row_per <- cbind(matches.scatter[i], org_row_per)
  colnames(org_row_per) <- c("Bucket","Percent_Change")
  
  #Create table with all % change in row count values for Orgs table
  org_row_change <- rbind(org_row_change,as.data.frame(org_row_per))
}

#Remove unnecessary text  
per_good_org2 <- as.data.frame(sapply(per_good_org,gsub,pattern="Total percent good = ",replacement=""))
per_good_org3 <- as.data.frame(sapply(per_good_org2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
org_row_change2 <- as.data.frame(sapply(org_row_change,gsub,pattern="%",replacement=""))
org_row_change3 <- as.data.frame(sapply(org_row_change2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
#Extra step to shorten Tea Leaves names
per_good_org4 <- as.data.frame(sapply(per_good_org3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))
org_row_change4 <- as.data.frame(sapply(org_row_change3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))

#Print buckets with change above/below threshold
if(hg_dir==1){
  #Run HealthGrades version
  #Convert percent to numeric and select rows where percent good is less than 80%
  per_good_org4$Percent_Good_Org <- as.numeric(as.character(per_good_org4$Percent_Good_Org))
  low_pg_org <- per_good_org4[which(per_good_org4$Percent_Good_Org < 80),]
  
  #Convert percent to numeric and select rows where abs value of row count change is > 20%
  org_row_change4$Percent_Change <- as.numeric(as.character(org_row_change4$Percent_Change))
  high_org_change <- org_row_change4[which(abs(org_row_change4$Percent_Change) > 20),]
}else if(grifols_dir==1){
  #Run Grifols version
  #Convert percent to numeric and select all rows
    per_good_org4$Percent_Good_Org <- as.numeric(as.character(per_good_org4$Percent_Good_Org))
    low_pg_org <- per_good_org4

  #Convert percent to numeric and select all rows
    org_row_change4$Percent_Change <- as.numeric(as.character(org_row_change4$Percent_Change))
    high_org_change <- org_row_change4
}else{
  #Run standard version
  #Convert percent to numeric and select rows where percent good is less than 95%
    per_good_org4$Percent_Good_Org <- as.numeric(as.character(per_good_org4$Percent_Good_Org))
    low_pg_org <- per_good_org4[which(per_good_org4$Percent_Good_Org < 95),]

  #Convert percent to numeric and select rows where abs value of row count change is > 3%
    org_row_change4$Percent_Change <- as.numeric(as.character(org_row_change4$Percent_Change))
    high_org_change <- org_row_change4[which(abs(org_row_change4$Percent_Change) > 3),]
}

# Percent Good: PxDx ----------------------------------------------------

#For each bucket's PxDx, loop through and pull Percent Good

for (i in 1:length(matches.scatter)){
  scatter_output <- read.delim(matches.scatter[i],header=F,sep="\t",as.is=T,row.names=NULL,stringsAsFactors = FALSE)
  
  #Find "Total % good" rows in scatterqc_output.txt files for Indivs table
  good_pxdx <- scatter_output[21,2]
  good_pxdx <- cbind(matches.scatter[i], good_pxdx)
  colnames(good_pxdx) <- c("Bucket","Percent_Good_PxDx")
  
  #Create table with all "Total % Good" values for PxDx table
  per_good_pxdx <- rbind(per_good_pxdx,as.data.frame(good_pxdx))
  
  #Find % change in row count in scatterqc_output.txt files for PxDx table
  pxdx_row_per <- scatter_output[5,5]
  pxdx_row_per <- cbind(matches.scatter[i], pxdx_row_per)
  colnames(pxdx_row_per) <- c("Bucket","Percent_Change")
  
  #Create table with all % change in row count values for PxDx table
  pxdx_row_change <- rbind(pxdx_row_change,as.data.frame(pxdx_row_per))
}

#Remove unnecessary text  
per_good_pxdx2 <- as.data.frame(sapply(per_good_pxdx,gsub,pattern="Total percent good = ",replacement=""))
per_good_pxdx3 <- as.data.frame(sapply(per_good_pxdx2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
pxdx_row_change2 <- as.data.frame(sapply(pxdx_row_change,gsub,pattern="%",replacement=""))
pxdx_row_change3 <- as.data.frame(sapply(pxdx_row_change2,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))
#Extra step to shorten Tea Leaves names
per_good_pxdx4 <- as.data.frame(sapply(per_good_pxdx3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))
pxdx_row_change4 <- as.data.frame(sapply(pxdx_row_change3,gsub,pattern="Neuro_NeuroSurg_Cardio_PxDx/",replacement=""))

#Print buckets with change above/below threshold
if(hg_dir==1){
  #Run HealthGrades version
  #Convert percent to numeric and select rows where percent good is less than 80%
  per_good_pxdx4$Percent_Good_PxDx <- as.numeric(as.character(per_good_pxdx4$Percent_Good_PxDx))
  low_pg_pxdx <- per_good_pxdx4[which(per_good_pxdx4$Percent_Good_PxDx < 80),]
  
  #Convert percent to numeric and select rows where abs value of row count change is > 20%
  pxdx_row_change4$Percent_Change <- as.numeric(as.character(pxdx_row_change4$Percent_Change))
  high_pxdx_change <- pxdx_row_change4[which(abs(pxdx_row_change4$Percent_Change) > 20),]
}else if(grifols_dir==1){
  #Run Grifols version
  #Convert percent to numeric and select all rows
    per_good_pxdx4$Percent_Good_PxDx <- as.numeric(as.character(per_good_pxdx4$Percent_Good_PxDx))
    low_pg_pxdx <- per_good_pxdx4

  #Convert percent to numeric and select all rows
    pxdx_row_change4$Percent_Change <- as.numeric(as.character(pxdx_row_change4$Percent_Change))
    high_pxdx_change <- pxdx_row_change4
}else{
  #Run standard version
  #Convert percent to numeric and select rows where percent good is less than 95%
    per_good_pxdx4$Percent_Good_PxDx <- as.numeric(as.character(per_good_pxdx4$Percent_Good_PxDx))
    low_pg_pxdx <- per_good_pxdx4[which(per_good_pxdx4$Percent_Good_PxDx < 95),]

  #Convert percent to numeric and select rows where abs value of row count change is > 3%
    pxdx_row_change4$Percent_Change <- as.numeric(as.character(pxdx_row_change4$Percent_Change))
    high_pxdx_change <- pxdx_row_change4[which(abs(pxdx_row_change4$Percent_Change) > 3),]
}

# Print Summary -----------------------------------------------------------

sink("scatterqc_percentgood.txt")
if(hg_dir==1){
  #Print summary of files where % good is < 80%
  cat("Indiv Percent Good < 80%:","\n")
  print(low_pg_indiv[order(low_pg_indiv[,2],low_pg_indiv[,1]),],row.names=FALSE)
  
  cat("\n\n","Org Percent Good < 80%:","\n")
  print(low_pg_org[order(low_pg_org[,2],low_pg_org[,1]),],row.names=FALSE)
  
  cat("\n\n","PxDx Percent Good < 80%:","\n")
  print(low_pg_pxdx[order(low_pg_pxdx[,2],low_pg_pxdx[,1]),],row.names=FALSE)
  
  cat("\n\n","Indiv Row Count Change > 20% or < -20%","\n")
  print(high_indiv_change[order(-high_indiv_change[,2]),],row.names=FALSE)
  
  cat("\n\n","Org Row Count Change > 20% or < -20%","\n")
  print(high_org_change[order(-high_org_change[,2]),],row.names=FALSE)
  
  cat("\n\n","PxDx Row Count Change > 20% or < -20%","\n")
  print(high_pxdx_change[order(-high_pxdx_change[,2]),],row.names=FALSE)
}else if(grifols_dir==1){
  #Grifols version
  cat("Indiv Percent Good:","\n")
  print(low_pg_indiv[order(low_pg_indiv[,2],low_pg_indiv[,1]),],row.names=FALSE)
  
  cat("\n\n","Org Percent Good:","\n")
  print(low_pg_org[order(low_pg_org[,2],low_pg_org[,1]),],row.names=FALSE)
  
  cat("\n\n","PxDx Percent Good:","\n")
  print(low_pg_pxdx[order(low_pg_pxdx[,2],low_pg_pxdx[,1]),],row.names=FALSE)
  
  cat("\n\n","Indiv Row Count Change","\n")
  print(high_indiv_change[order(-high_indiv_change[,2]),],row.names=FALSE)
  
  cat("\n\n","Org Row Count Change","\n")
  print(high_org_change[order(-high_org_change[,2]),],row.names=FALSE)
  
  cat("\n\n","PxDx Row Count Change","\n")
  print(high_pxdx_change[order(-high_pxdx_change[,2]),],row.names=FALSE)
}else{
  #Print summary of files where % good is < 95%
  cat("Indiv Percent Good < 95%:","\n")
  print(low_pg_indiv[order(low_pg_indiv[,2],low_pg_indiv[,1]),],row.names=FALSE)
  
  cat("\n\n","Org Percent Good < 95%:","\n")
  print(low_pg_org[order(low_pg_org[,2],low_pg_org[,1]),],row.names=FALSE)
  
  cat("\n\n","PxDx Percent Good < 95%:","\n")
  print(low_pg_pxdx[order(low_pg_pxdx[,2],low_pg_pxdx[,1]),],row.names=FALSE)
  
  cat("\n\n","Indiv Row Count Change > 3% or < -3%","\n")
  print(high_indiv_change[order(-high_indiv_change[,2]),],row.names=FALSE)
  
  cat("\n\n","Org Row Count Change > 3% or < -3%","\n")
  print(high_org_change[order(-high_org_change[,2]),],row.names=FALSE)
  
  cat("\n\n","PxDx Row Count Change > 3% or < -3%","\n")
  print(high_pxdx_change[order(-high_pxdx_change[,2]),],row.names=FALSE)
}


# Average Change Across Buckets -------------------------------------------

#Shows average row count change across all buckets. This makes sure that there has been
#at least some churn (i.e., the data doesn't look good b/c it is exactly the same 
#as previous run)
cat("\n\n\n","Average Row Count Change Across All Indiv Files:","\t")
cat(mean(indiv_row_change4$Percent_Change,na.rm=T))
cat("\n","Average Row Count Change Across All Org Files:","\t")
cat(mean(org_row_change4$Percent_Change,na.rm=T))
cat("\n","Average Row Count Change Across All PxDx Files:","\t")
cat(mean(pxdx_row_change4$Percent_Change,na.rm=T))


#Shows average percent good across all buckets
cat("\n\n\n","Average Percent Good Across All Indiv Files:","\t")
cat(mean(per_good_indiv4$Percent_Good_Indiv,na.rm=T))
cat("\n","Average Percent Good Across All Org Files:","\t")
cat(mean(per_good_org4$Percent_Good_Org,na.rm=T))
cat("\n","Average Percent Good Across All PxDx Files:","\t")
cat(mean(per_good_pxdx4$Percent_Good_PxDx,na.rm=T))


sink()


# NEW Addition July 2018: Org Total Volume Change ------------------------

#Set up empty data object to store data
org_vol_change_all<-data.frame(V1=character(),V2=character(),stringsAsFactors=FALSE)
colnames(org_vol_change_all)<-c("Bucket","Org_Volume_Change")

#For each bucket's PxDx, loop through and pull Org Total Percent Change
for (i in 1:length(matches.scatter)){
  scatter_output <- read.delim(matches.scatter[i],header=F,sep="\t",as.is=T,row.names=NULL,stringsAsFactors = FALSE)
  
  #If bucket has no data, it will not have an org volume change number. Check for this and skip.
 if(length(grep("Org Total Volume",scatter_output$V1)) != 0){
  #Find "Org Total Volume Percent Change" row in scatterqc_output.txt files
  org_vol_change <- grep("Org Total Volume",scatter_output$V1,value=T)
  org_vol_change <- cbind(matches.scatter[i], org_vol_change)
  org_vol_change<-as.data.frame(org_vol_change)
  colnames(org_vol_change)<-c("Bucket","Org_Volume_Change")

  #Create table with all "Org Total Volume Percent Change" values
  org_vol_change_all <- rbind(org_vol_change_all,as.data.frame(org_vol_change))
 }else{
   sink("scatterqc_percentgood.txt",append = T) 
   cat("\n\nSkipping ",matches.scatter[i],"as it does not contain the org total volume metric.")
   sink()
   }
}


#Remove unnecessary text
org_vol_change_all2 <- as.data.frame(sapply(org_vol_change_all,gsub,pattern="Org Total Volume Percent Change: ",replacement=""))
org_vol_change_all3 <- as.data.frame(sapply(org_vol_change_all2,gsub,pattern="%",replacement=""))
org_vol_change_all4 <- as.data.frame(sapply(org_vol_change_all3,gsub,pattern="/QA/scatterqc_output.txt",replacement=""))

#Convert volume column to numeric
org_vol_change_all4$Org_Volume_Change<-as.numeric(as.character(org_vol_change_all4$Org_Volume_Change))

#Add column with absolute value
org_vol_change_all4$Abs_Org_Volume_Change<-abs(org_vol_change_all4$Org_Volume_Change)

#Sort by absolute value volume change
sink("scatterqc_org_volumes.txt")
print(org_vol_change_all4_sort<-org_vol_change_all4[order(-org_vol_change_all4[,3]),],row.names=FALSE)

sink()


#Shows average org volume change
sink("scatterqc_percentgood.txt",append = T)
cat("\n\n\n","Average Org Volume Change Across All Org Files:","\t")
cat(mean(org_vol_change_all4$Org_Volume_Change))
cat("\n","Minimum Org Volume Change Across All Org Files:","\t")
cat(min(org_vol_change_all4$Org_Volume_Change))
cat("\n","Maximum Org Volume Change Across All Org Files:","\t")
cat(max(org_vol_change_all4$Org_Volume_Change))

cat("\n\nNumber of buckets included:",length(matches.scatter))

##Add note about which version of script was run
if(hg_dir==1){
cat("\n\nVersion of script run: HealthGrades")
  }else if(grifols_dir==1){
  cat("\n\nVersion of script run: Grifols")  
}else{
  cat("\n\nVersion of script run: Standard")
  }

sink()
