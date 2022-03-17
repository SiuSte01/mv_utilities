args = commandArgs(trailingOnly=TRUE)

if (length(args) < 2) {
  stop("Required args: milestones_dir updated_addresses", call.=FALSE)
}

milestones_dir = args[1]
updated_addresses = args[2]


source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")


new<-read.hms(updated_addresses)
#orgs<-read.hms("/vol/cs/clientprojects/VGM/2017_03_31_BCP_Group_Custom_Orthotics/milestones/organizations_sample.tab.bak")
#pxdx<-read.hms("/vol/cs/clientprojects/VGM/2017_03_31_BCP_Group_Custom_Orthotics/milestones/pxdx_sample.tab.bak")

orgs<-read.hms(paste(milestones_dir,"organizations_sample.tab",sep="/"))
pxdx<-read.hms(paste(milestones_dir,"pxdx_sample.tab",sep="/"))


#update orgs
orgs[which(orgs$NPI %in% new$NPI),c(2:10)]<-new[match(orgs$NPI[which(orgs$NPI %in% new$NPI)],new$NPI),c(5:13)]


#add poid to new because pxdx doesn't have NPI
new$HMS_POID<-orgs$HMS_POID[match(new$NPI,orgs$NPI)]

pxdx[which(pxdx$HMS_POID %in% new$HMS_POID),c(13:16)]<-new[match(pxdx$HMS_POID[which(pxdx$HMS_POID %in% new$HMS_POID)],new$HMS_POID),c(5,8:10)]

file.rename(paste(milestones_dir,"organizations_sample.tab",sep="/"),paste(milestones_dir,"organizations_sample.tab.bak",sep="/"))
file.rename(paste(milestones_dir,"pxdx_sample.tab",sep="/"),paste(milestones_dir,"pxdx_sample.tab.bak",sep="/"))

write.hms(orgs,paste(milestones_dir,"organizations_sample.tab",sep="/"))
write.hms(pxdx,paste(milestones_dir,"pxdx_sample.tab",sep="/"))



