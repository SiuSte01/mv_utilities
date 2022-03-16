source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

indivs<-read.hms("individuals_sample.tab.bak")

reorder<-indivs[,c(1:17,19,18)]

write.hms(reorder,"individuals_sample.tab")



