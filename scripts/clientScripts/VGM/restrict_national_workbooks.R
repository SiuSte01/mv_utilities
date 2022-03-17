source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

indivs_path<-"/vol/cs/clientprojects/VGM/2017_09_19_Oxygen_One_Oxygen_Sleep/Oxygen/QA/individuals.tab"
orgs_path<-"/vol/cs/clientprojects/VGM/2017_09_19_Oxygen_One_Oxygen_Sleep/Oxygen/QA/organizations.tab"
pxdx_path<-"/vol/cs/clientprojects/VGM/2017_09_19_Oxygen_One_Oxygen_Sleep/Oxygen/QA/pxdx.tab"

dx_column<-"Dx_PRACTITIONER_NATL_RANK"
px_column<-"Oxygen_PRACTITIONER_NATL_RANK"
pxdx_column<-"Oxygen_PRACTITIONER_FAC_RANK"

indivs<-read.hms(indivs_path)
orgs<-read.hms(orgs_path)
pxdx<-read.hms(pxdx_path)

results<-data.frame(Num=character(),indivs=character(),orgs=character(),pxdx=character())

 res.p<-pxdx[which(! is.na(pxdx[[px_column]]) & ! is.na(pxdx[[pxdx_column]])),]
 res.o<-orgs[which(orgs$HMS_POID %in% res.p$HMS_POID),]

for (i in seq(1,9)){
 remove<-indivs$HMS_PIID[which(indivs[[dx_column]] <= i & is.na(indivs[[px_column]]))]
 temp.i<-indivs[which(! indivs$HMS_PIID %in% remove),]
 temp.p<-res.p[which(res.p$HMS_PIID %in% temp.i$HMS_PIID),]
 temp.o<-res.o[which(res.o$HMS_POID %in% temp.p$HMS_POID),]
 temp.res<-as.data.frame(t(c(i,nrow(temp.i),nrow(temp.o),nrow(temp.p))))
 results<-rbind(results,temp.res)
}

print(results)


results2<-data.frame(Num=character(),Num2=character(),indivs=character(),orgs=character(),pxdx=character())

for (i in seq(1,9)){
 for (j in seq(1,5)){
 remove<-indivs$HMS_PIID[which((indivs[[dx_column]] <= i & is.na(indivs[[px_column]])) | (indivs[[dx_column]] <= i & indivs[[px_column]] <= j))]
 temp.i<-indivs[which(! indivs$HMS_PIID %in% remove),]
 temp.p<-pxdx[which(pxdx$HMS_PIID %in% temp.i$HMS_PIID),]
 temp.o<-orgs[which(orgs$HMS_POID %in% temp.p$HMS_POID),]
 temp.res<-as.data.frame(t(c(i,j,nrow(temp.i),nrow(temp.o),nrow(temp.p))))
 results2<-rbind(results2,temp.res)
}
}

print(results2)


