###this script is designed to run in a milestones directory, and using indivs, pxdx, and orgs, create poid lists of orgs w/o hospital in the org type, and indivs with volue at those centers. These can then be used as PIID and POID lists for regionalfilter.R

source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

indivs<-read.hms("individuals.tab",y=c("ZIP","ZIP4"))
orgs<-read.hms("organizations.tab",y=c("ZIP","ZIP4"))
pxdx<-read.hms("pxdx.tab",y=c("ZIP","ZIP4"))

hospital_orgtypes<-unique(orgs$ORGTYPE[grep("Hospital",orgs$ORGTYPE)])

state<-"IL"

orgs_filtered<-orgs[which((! orgs$ORGTYPE %in% hospital_orgtypes) & orgs$STATE == state),]
pxdx_filtered<-pxdx[which(pxdx$HMS_POID %in% orgs_filtered$HMS_POID),]
indivs_filtered<-indivs[which(indivs$HMS_PIID %in% pxdx_filtered$HMS_PIID),]

write.hms(orgs_filtered$HMS_POID,"poidlist_filtered.tab")
write.hms(indivs_filtered$HMS_PIID,"piidlist_filtered.tab")


###in the first run of this, orgs only dropped from 225413 to 213605, ~5%. pxdx dropped from 3313906 to 1169833. indivs from 1096273 to 657414
###using state further decreased - orgs: 9143 pxdx: 51324 indivs: 29787



