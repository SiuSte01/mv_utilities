directory<-"/vol/cs/clientprojects/VGM/2017_09_25_PT_general_refresh/MV/Dx/QA"
INA_directory<-"/vol/cs/clientprojects/VGM/2017_09_25_PT_general_refresh/INA/Evaluations/Comb/new_Filter_West"

#directory<-"/vol/cs/clientprojects/VGM/2017_09_25_PT_general_refresh/MV/Dx/QA"
#INA_directory<-"/vol/cs/clientprojects/VGM/2017_09_25_PT_general_refresh/INA/Evaluations/Comb/Filter_NJ_NY_Counties_Excel_Orthopedic"

#directory<-"/vol/cs/clientprojects/VGM/2017_07_05_Performance_PT_Evaluations_RERUN/MV/Dx/QA"
#INA_directory<-"/vol/cs/clientprojects/VGM/2017_07_05_Performance_PT_Evaluations_RERUN/INA/Evaluations/Comb/PA_DE_filter"

#directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_New/Dx/QA"
#INA_directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_INA/Physical_Therapy_INA/Comb/RI_AttleboroMA_2017_07_11"

#directory<-"/vol/cs/clientprojects/VGM/2017_07_05_Performance_PT_Evaluations_RERUN/MV/Dx/QA"
#INA_directory<-"/vol/cs/clientprojects/VGM/2017_07_05_Performance_PT_Evaluations_RERUN/INA/Evaluations/Comb/Filter"

#directory<-"/vol/cs/clientprojects/VGM/2017_06_02_Performance_Physical_Therapy_Evaluations/MV/Dx/QA"
#INA_directory<-"/vol/cs/clientprojects/VGM/2017_06_02_Performance_Physical_Therapy_Evaluations/INA/Evaluations/Comb/Filter"

#directory<-"/vol/cs/clientprojects/VGM/2017_06_02_Performance_Physical_Therapy_Evaluations/MV/Dx/milestones"
#INA_directory<-"/vol/cs/clientprojects/VGM/2017_06_02_Performance_Physical_Therapy_Evaluations/INA/Evaluations/Comb/Filter"

#directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_Dx/milestones"
#INA_directory<-"/vol/cs/clientprojects/VGM/2016_08_25_RET_Physical_Therapy_INA/Physical_Therapy_INA/Comb/WA_New"

###filter indivs
olddir<-getwd()
setwd(directory)

source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
indivs<-read.hms("individuals.tab")
indivs2<-indivs[which(indivs$Dx_PRACTITIONER_NATL_RANK > 4 | indivs$HMS_SPEC1 %in% c('Internal Medicine','Family Practice','Nurse Practitioner','Assistive Therapy','Physician Assistant','Chiropractor','Pediatrics','Emergency Medicine','Anesthesiology','Obstetrics & Gynecology','Radiology, Diagnostic','Surgery, Orthopedic','Surgery, General','Cardiology')),]
write.hms(indivs2,"individuals_filtered.tab")

#filter INA
setwd(INA_directory)
ina<-read.hms("network.txt")
ina2<-ina[which(! ina$ORG_TYPE_2 %in% c("Hospital, Ambulatory Surgical Center","Hospital, Unspecified","Hospital Specialty, Psychiatric")),]
ina2<-ina2[which(! ina2$PRACTITIONER_TYPE_1 %in% c('Anesthesiology','Assistive Therapy','Certified Registered Nurse Anesthetist','Radiology, Diagnostic')),]

write.hms(ina2,"network_filtered.txt")

setwd(olddir)





























