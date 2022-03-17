source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

args<-commandArgs(trailingOnly=TRUE)
incols<-args[-1]
outcols<-args[1]

print(paste("px cols:",paste(incols,collapse=" ")))
print(paste("dx col:",paste(outcols,collapse=" ")))

#stop("testing")

#incols<-c("Manual_Wheelchairs_PRACTITIONER_TERR_RANK","Power_Wheelchairs_PRACTITIONER_TERR_RANK")
#outcols<-c("Dx_PRACTITIONER_TERR_RANK")

if(length(outcols) > 1){stop("currently only works with one Dx column") }

testdata<-read.hms("pxdx_sample.tab",scanlen=1500)

inlist<-colnames(testdata) %in% incols
outlist<-colnames(testdata) %in% outcols

filtereddata<-testdata[which(rowSums(testdata[,c(incols)],na.rm=T)==0),]

output<-data.frame("cut_rank"="all","indivs"=length(unique(testdata$HMS_PIID)),"orgs"=length(unique(testdata$HMS_POID)),"pxdx"=nrow(testdata),stringsAsFactors=F)


for (i in sort(unique(filtereddata[,outcols]))){
 temp<-filtereddata[which(filtereddata[,outcols] <= i),]
 npxdx<-nrow(testdata)-nrow(temp)
 npiid<-length(unique(testdata$HMS_PIID))-length(unique(temp$HMS_PIID))
 npoid<-length(unique(testdata$HMS_POID))-length(unique(temp$HMS_POID))
 
 tempoutput<-data.frame("cut_rank"=as.character(i),"indivs"=npiid,"orgs"=npoid,"pxdx"=npxdx,stringsAsFactors=F)

 output<-rbind(output,tempoutput)
}

print(output)



