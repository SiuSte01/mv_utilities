#this version of makeview.R is intended for unprojected projects

#read tables and replace column IDs without bucket names
#assume that there is only 1 bucket in each of the 3 files from the PxDx
indivs<-read.table("individuals.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T)
#get rid of Terr columns if exist
i0<-grep("Terr",colnames(indivs))
if(length(i0) > 0) {
 indivs<-indivs[,-i0]
}
i1<-grep("PRACTITIONER_NATL_RANK",colnames(indivs))
i2<-grep("PRACTITIONER_TOTAL",colnames(indivs))
colnames(indivs)[i1]<-"PHYS_NATL_RANK"
colnames(indivs)[i2]<-"COUNT"
#set the fax column name to FAX1 - assume only 1 fac col
idx<-grep("FAX",colnames(indivs))
colnames(indivs)[idx]<-"FAX"

network<-read.table("network.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T)

pxdx<-read.table("pxdx.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T)
i1<-grep("PRACTITIONER_NATL_RANK",colnames(pxdx))
i2<-grep("FAC_NATL_RANK",colnames(pxdx))
i3<-grep("PRACTITIONER_FAC_TOTAL",colnames(pxdx))
i4<-grep("PRACTITIONER_FAC_RANK",colnames(pxdx))
colnames(pxdx)[i1]<-"PHYS_NATL_RANK"
colnames(pxdx)[i2]<-"FAC_NATL_RANK"
colnames(pxdx)[i3]<-"PHYS_FAC_COUNT"
colnames(pxdx)[i4]<-"PHYS_FAC_RANK"

#if pxdx doesnt have org npi, need to read orgs file and get it from there
#merge it into the pxdx table
idx<-grep("NPI",colnames(pxdx))
if(length(idx) == 0 ) {
 orgs<-read.table("organizations.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T)

#reorder columns for a new orgs view and output
orgs.new<-orgs
rank.col<-grep("RANK",colnames(orgs.new))
rank.col.name<-colnames(orgs.new)[rank.col]
wantcols<-c("HMS_POID","NPI","ORGNAME","ORGTYPE","ADDRESS1","CITY",
"STATE","ZIP","PHONE1","FAX1",rank.col.name)
orgs.new<-orgs.new[,wantcols]
write.table(orgs.new,file="orgs_view.txt",col.names=F,row.names=F,
quote=F,sep="\t",na="")

 orgs<-orgs[,c("HMS_POID","NPI")]
 pxdx<-merge(pxdx,orgs,by.x="HMS_POID",by.y="HMS_POID")
}
#if pxdx has phone/fax info, remove it
i1<-grep("PHONE",colnames(pxdx))
i2<-grep("FAX",colnames(pxdx))
i3<-c(i1,i2)
if(length(i3) > 0) {
 pxdx<-pxdx[,-i3]
}

orgs.frompxdx<-pxdx[,c("HMS_POID","ORGNAME","ADDRESS1","ADDRESS2",
"CITY","STATE","ZIP","ZIP4")]
orgs.frompxdx<-cbind(orgs.frompxdx,rep("",nrow(orgs.frompxdx)))
colnames(orgs.frompxdx)[ncol(orgs.frompxdx)]<-"PHONE1"
orgs.frompxdx<-cbind(orgs.frompxdx,rep("",nrow(orgs.frompxdx)))
colnames(orgs.frompxdx)[ncol(orgs.frompxdx)]<-"PHONE2"
orgs.frompxdx<-cbind(orgs.frompxdx,rep("",nrow(orgs.frompxdx)))
colnames(orgs.frompxdx)[ncol(orgs.frompxdx)]<-"FAX1"
orgs.frompxdx<-cbind(orgs.frompxdx,pxdx[,c("ORGTYPE","FAC_NATL_RANK")])

phys.count<-tapply(pxdx$PHYS_FAC_COUNT,pxdx$HMS_PIID,sum,na.rm=T)
pxdx<-merge(pxdx,phys.count,by.x="HMS_PIID",by.y=0)
colnames(pxdx)[ncol(pxdx)]<-"Phys.Total"
calc.workload<-signif(pxdx$PHYS_FAC_COUNT/pxdx$Phys.Total,3)
pxdx<-cbind(pxdx,calc.workload)
cutoff<-seq(0.1,0.3,0.05)
for(cut in cutoff)
{
 cname<-paste("workload",100*cut,sep="")
 work.flag<-rep.int(0,nrow(pxdx))
 work.flag[which(calc.workload >= cut)]<-1
 pxdx<-cbind(pxdx,work.flag)
 colnames(pxdx)[ncol(pxdx)]<-cname 
}

phys.max.workload<-tapply(pxdx$calc.workload,pxdx$HMS_PIID,max,na.rm=T)
workload.sums<-rowsum(pxdx[,c("workload10","workload15","workload20",
 "workload25","workload30")],pxdx$HMS_PIID,na.rm=T)
colnames(workload.sums)<-c("work10","work15","work20", "work25","work30")
pxdx<-merge(pxdx,phys.max.workload,by.x=1,by.y=0)
colnames(pxdx)[ncol(pxdx)]<-"Max.workload"
pxdx<-merge(pxdx,workload.sums,by.x=1,by.y=0)

pxdx.forexport<-merge(pxdx,indivs,by.x="HMS_PIID",by.y="HMS_PIID")
wantc<-c("HMS_PIID","HMS_POID","NPI.x","FIRST.y","LAST.y","SUFFIX.y","CRED.y",
"HMS_SPEC1.y","HMS_SPEC2.y","ADDRESS1.y","CITY.y","STATE.y","ZIP.y",
"PHONE1","FAX","ORGNAME","ORGTYPE","CITY.x","STATE.x","PHYS_NATL_RANK.y",
"FAC_NATL_RANK","PHYS_FAC_RANK","calc.workload",
"Max.workload","work30","work25","work20","work15","work10")
pxdx.forexport<-pxdx.forexport[,wantc]
write.table(pxdx.forexport,file="pxdx_view.txt",row.names=F,col.names=F,
sep="\t",quote=F,na="")

#find poid with max workload for each piid
pxdx.formaxpoid<-pxdx[,c("HMS_PIID","HMS_POID","calc.workload",
 "Max.workload")]
idx<-which(pxdx.formaxpoid$calc.workload==pxdx.formaxpoid$Max.workload)
pxdx.maxpoid<-pxdx.formaxpoid[idx,]
#deal with ties
pxdx.maxpoid2<-as.data.frame(tapply(pxdx.maxpoid$HMS_POID,pxdx.maxpoid$HMS_PIID,min))
#merge back max workload
pxdx.maxworkload<-merge(pxdx.maxpoid2,phys.max.workload,by.x=0,by.y=0)
colnames(pxdx.maxworkload)<-c("HMS_PIID","HMS_POID","Max.workload")

#create a piid, poid, maxworkloadorgname dataset
org.wname<-unique(orgs.frompxdx[,c("HMS_POID","ORGNAME")])
maxworkload.wname<-merge(pxdx.maxworkload,org.wname,
by.x="HMS_POID",by.y="HMS_POID")
maxworkload.wname<-maxworkload.wname[,c("HMS_PIID","ORGNAME")]

#indivs view
#get it from the pxdx view above, by picking columns and then deduping
wantc2<-c("HMS_PIID","FIRST.y","LAST.y","SUFFIX.y","CRED.y",
"HMS_SPEC1.y","HMS_SPEC2.y","ADDRESS1.y","CITY.y","STATE.y","ZIP.y",
"PHONE1","FAX","PHYS_NATL_RANK.y", 
"Max.workload","work30","work25","work20","work15","work10")
indivs.view<-unique(pxdx.forexport[,wantc2])
indivs.view<-merge(indivs.view,maxworkload.wname,
by.x="HMS_PIID",by.y="HMS_PIID")
#deal with blank columns and column order
blankcol<-rep("",nrow(indivs.view))
indivs.view2<-cbind(indivs.view$HMS_PIID,blankcol)
colnames(indivs.view2)[1]<-"HMS_PIID"
colnames(indivs.view2)[ncol(indivs.view2)]<-"NPI"
indivs.view2<-cbind(indivs.view2,indivs.view$FIRST.y)
colnames(indivs.view2)[ncol(indivs.view2)]<-"FIRST.y"
indivs.view2<-cbind(indivs.view2,blankcol)
colnames(indivs.view2)[ncol(indivs.view2)]<-"MIDDLE"
indivs.view2<-cbind(indivs.view2,indivs.view[,c("LAST.y","SUFFIX.y","CRED.y",
"HMS_SPEC1.y","HMS_SPEC2.y","ADDRESS1.y","CITY.y","STATE.y","ZIP.y",
"PHONE1","FAX","PHYS_NATL_RANK.y")])
indivs.view2<-cbind(indivs.view2,indivs.view2$PHYS_NATL_RANK.y)
indivs.view2<-cbind(indivs.view2,indivs.view[,c("ORGNAME",
"Max.workload","work30","work25","work20","work15","work10")])
#export
write.table(indivs.view2,file="indivs_view.txt",
row.names=F,col.names=F,quote=F,sep="\t",na="")



#Diverter list
terr.networksize<-table(network$HMS_PIID1)
diverter.list<-unique(network[,c("HMS_PIID1","NPI_1","FIRST_1",
"LAST_1","HMS_SPEC1_1","HMS_SPEC2_1","ADDRESS1_1",
"CITY_1","STATE_1","ZIP_1","COUNTY_1")])
diverter.list<-merge(diverter.list,as.data.frame(terr.networksize),by.x="HMS_PIID1",by.y=1)
indiv.natlrank<-indivs[,c("HMS_PIID","PHYS_NATL_RANK")]
diverter.list<-merge(diverter.list,indiv.natlrank,by.x=1,by.y=1)


#Diverter counts
diverter.counts<-network[,c("HMS_PIID1","HMS_PIID2")]
pxdx.physrank<-unique(pxdx[,c("HMS_PIID","PHYS_NATL_RANK")])
diverter.counts<-merge(diverter.counts,pxdx.physrank,by.x="HMS_PIID2",
by.y="HMS_PIID",all.x=T)
diverter.counts<-merge(diverter.counts,phys.max.workload,by.x=1,by.y=0,all.x=T)
colnames(diverter.counts)[ncol(diverter.counts)]<-"Max.workload"
for(wrkcut in c(50,40,30,20,10))
{
 for(rankcut in seq(10,6,-1))
 {
  cname<-paste("loyal",rankcut,sep="")
  cname<-paste(cname,wrkcut,sep="_")
  flag<-rep.int(0,nrow(diverter.counts))
  wrkcut.fr<-wrkcut/100
  idx<-which(diverter.counts$Max.workload >= wrkcut.fr)
  flag[idx]<-1
  flag[which(diverter.counts$PHYS_NATL_RANK < rankcut)]<-0
  diverter.counts<-cbind(diverter.counts,flag)
  colnames(diverter.counts)[ncol(diverter.counts)]<-cname
 }
}

#do the sum of loyal data
sumofloyal<-rowsum(diverter.counts[,c(5:29)],diverter.counts$HMS_PIID1,na.rm=T)

#Diverter view and export
#build up columns of diverter view
diverter.view<-diverter.list[,c(1:12)]
blankcols<-rep("",nrow(diverter.list))
diverter.view<-cbind(diverter.view,blankcols)
colnames(diverter.view)[ncol(diverter.view)]<-"NATLNETSIZE"
diverter.view<-cbind(diverter.view,diverter.list[,13])
diverter.view<-cbind(diverter.view,blankcols)
colnames(diverter.view)[ncol(diverter.view)]<-"CLIENTHCO"
diverter.view<-cbind(diverter.view,blankcols)
colnames(diverter.view)[ncol(diverter.view)]<-"CLIENTHCP"
diverter.view<-merge(diverter.view,sumofloyal,by.x="HMS_PIID1",
by.y=0)

write.table(diverter.view,file="diverter_view.txt",
row.names=F,col.names=F,quote=F,sep="\t",na="")


#conn phys view and export
#create a piid, poid, maxworkloadorgname,city,state dataset
org.wname<-unique(orgs.frompxdx[,c("HMS_POID","ORGNAME","CITY","STATE")])
maxworkload.wnameplus<-merge(pxdx.maxworkload,org.wname,
by.x="HMS_POID",by.y="HMS_POID")
maxworkload.wnameplus<-maxworkload.wnameplus[,c("HMS_PIID","ORGNAME",
"CITY","STATE","Max.workload")]
#grab wanted columns from the network file
wantc3<-c( "HMS_PIID1", "HMS_PIID2", "NPI_2", "FIRST_2", "LAST_2",
"HMS_SPEC1_2", "HMS_SPEC2_2", "ADDRESS1_2", "CITY_2", "STATE_2",
"ZIP_2", "COUNTY_2")
#if shared patients exist in network, dump it to view
idx<-grep("SharedPatientCount",colnames(network))
if(length(idx) > 0) {
  wantc3<-c(wantc3,"SharedPatientCount")
}
wantc3<-c(wantc3, "TERR_SOR_VALUE", "Dx_VOLUME_NATL_RANK2", "PCT1")
network2<-network[,wantc3]
network2<-merge(network2,maxworkload.wnameplus,
by.x="HMS_PIID2",by.y="HMS_PIID",all.x=T)

#reorder col1 and col2
cols<-colnames(network2)
cols2<-cols[c(2,1,3:length(cols))]
network2<-network2[,cols2]

write.table(network2,file="connected_physicians_view.txt",
row.names=F,col.names=F,sep="\t",na="",quote=F)







