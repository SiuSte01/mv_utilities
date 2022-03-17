source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

orgs<-read.hms("organizations_sample.tab")
pxdx<-read.hms("pxdx_sample.tab")
orgs2<-orgs[,c(-14,-17)]
pxdx2<-pxdx[,c(-22,-28)]
write.hms(orgs2,"organizations_sample.tab")
write.hms(pxdx2,"pxdx_sample.tab")


