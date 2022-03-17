args = commandArgs(trailingOnly=TRUE)
directory=args[1]
INA_directory=args[2]

#directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_Dx/milestones"
#INA_directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_INA/Physical_Therapy_INA/Comb/WA_New"

if(length(args) != 2){
 stop("This script requires 2 arguments, a milestones directory and a filtered INA directory. If you want to skip filtering either, list the path as 'none'.")
}

###filter indivs
olddir<-getwd()

if(directory != "none"){
 print(paste("running indivs filter on",directory))
 setwd(directory)
 source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
 indivs<-read.hms("individuals.tab")
 indivs2<-indivs[which(indivs$Dx_PRACTITIONER_NATL_RANK > 4 | indivs$HMS_SPEC1 %in% c('Internal Medicine','Family Practice','Nurse Practitioner','Assistive Therapy','Physician Assistant','Chiropractor','Pediatrics','Emergency Medicine','Anesthesiology','Obstetrics & Gynecology','Radiology, Diagnostic','Surgery, Orthopedic','Surgery, General','Cardiology')),]
 write.hms(indivs2,"individuals_filtered.tab")
}else{
 print("directory set to 'none'. Indivs filter will not be run")
}

#filter INA
if(INA_directory != "none"){
 print(paste("running INA filter on",INA_directory))
 setwd(INA_directory)
 ina<-read.hms("network.txt")
 ina2<-ina[which(! ina$ORG_TYPE_2 %in% c("Hospital, Ambulatory Surgical Center","Hospital, Unspecified","Hospital Specialty, Psychiatric")),]
 write.hms(ina2,"network_filtered.txt")
}else{
 print("INA directory set to 'none'. INA filter will not be run")
}

setwd(olddir)





























