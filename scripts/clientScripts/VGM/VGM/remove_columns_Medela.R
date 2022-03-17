indivs<-read.hms("individuals.tab")
orgs<-read.hms("organizations.tab")
pxdx<-read.hms("pxdx.tab")

indivs.sub<-indivs[,c(-21,-22)]
indivs.sub<-indivs.sub[which(!is.na(indivs.sub$NPWT_PRACTITIONER_NATL_RANK) | !is.na(indivs.sub$NPWT_dx_PRACTITIONER_NATL_RANK)),]

pxdx.sub<-pxdx[,c(-35,-32,-27,-26,-25)]
pxdx.sub<-pxdx.sub[which(!is.na(pxdx.sub$NPWT_WORKLOAD) | !is.na(pxdx.sub$NPWT_dx_WORKLOAD)),]

orgs.sub<-orgs[,c(-17,-16)]
orgs.sub<-orgs.sub[which(!is.na(orgs.sub$NPWT_FAC_NATL_RANK) | !is.na(orgs.sub$NPWT_dx_FAC_NATL_RANK)),]

write.hms(indivs.sub,"individuals_NPWT.tab")
write.hms(orgs.sub,"organizations_NPWT.tab")
write.hms(pxdx.sub,"pxdx_NPWT.tab")
