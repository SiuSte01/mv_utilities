#12/3/2015
#enhance to make it compatible with new DB headers in network.txt

#7/1/2015: correct the issue of pxdx being starred
#  should not be since the pxdx_forbiltmore being symlinked to pxdx.txt
#  is already starred.  double starring was happening between mar 2015
# and now, and it would have converted counts like 100, 101, etc - until 110
#   to *, because they are < 11 in a character comparison


#version of makeview that works on projected projects that include
#a counts column
#first create the function to star out low counts
dostar<-function(d)
{
 idx1<-grep("TOTAL",colnames(d))
 idx2<-grep("COUNT",colnames(d))
 idx<-union(idx1,idx2)
 for(i in idx)
 {
  low.idx<-which(d[,i]<11)
  if(length(low.idx) > 0) {
    d[low.idx,i]<-"*"
  }
 }
 d
}

#read tables and replace column IDs without bucket names
#assume that there is only 1 bucket in each of the 3 files from the PxDx
indivs<-read.table("individuals.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T,
colClasses=c(ZIP="character",ZIP4="character"),na.strings="")

#first make sure the counts col in indivs is not numeric
#need there to be *s in it, and not all numeric
#if(is.numeric(indivs[,i2])) {
# cat("indivs count is all numeric, did you remember to use starred version?\n")
# quit()
#}

#replace NATL rank with TERR rank if latter exists
#and get rid of TERR column
#col name of the rank column will stay as NATL, even though it is actually TERR
i0<-grep("TERR",colnames(indivs))
if(length(i0) > 0) {
 indivs.terr.rank<-indivs[,c("HMS_PIID",colnames(indivs)[i0])] 
 i1<-grep("PRACTITIONER_NATL_RANK",colnames(indivs))
 indivs[,i1]<-indivs[,i0]
 indivs<-indivs[,-i0]
}
i1<-grep("PRACTITIONER_NATL_RANK",colnames(indivs))
i2<-grep("PRACTITIONER_TOTAL",colnames(indivs))
colnames(indivs)[i1]<-"PHYS_NATL_RANK"
colnames(indivs)[i2]<-"COUNT"
indivs.count<-indivs[,c("HMS_PIID","COUNT")]
#set the fax column name to FAX1 - assume only 1 fac col
idx<-grep("FAX",colnames(indivs))
colnames(indivs)[idx]<-"FAX"

network<-read.table("network.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T,
colClasses=c(ZIP_1="character",ZIP4_1="character",
ZIP_2="character",ZIP4_2="character"),na.strings="")

pxdx<-read.table("pxdx.txt",header=T,sep="\t",
as.is=T,quote="",comment.char="",fill=T,
colClasses=c(ZIP="character",ZIP4="character"),na.strings="")
i1<-grep("PRACTITIONER_NATL_RANK",colnames(pxdx))
i2<-grep("FAC_NATL_RANK",colnames(pxdx))
i3<-grep("PRACTITIONER_FAC_TOTAL",colnames(pxdx))
i4<-grep("PRACTITIONER_FAC_RANK",colnames(pxdx))
colnames(pxdx)[i1]<-"PHYS_NATL_RANK"
colnames(pxdx)[i2]<-"FAC_NATL_RANK"
colnames(pxdx)[i3]<-"PHYS_FAC_COUNT"
colnames(pxdx)[i4]<-"PHYS_FAC_RANK"
rng.wrk.col<-grep("EXACT",grep("WORKLOAD",colnames(pxdx),val=T),invert=T,val=T)
exact.wrk.col<-grep("EXACT",grep("WORKLOAD",colnames(pxdx),val=T),val=T)
i5<-grep(rng.wrk.col,colnames(pxdx))
i6<-grep(exact.wrk.col,colnames(pxdx))
colnames(pxdx)[i5]<-"WORKLOAD"
colnames(pxdx)[i6]<-"EXACT.WORKLOAD"
pxdx$EXACT.WORKLOAD<-as.numeric(sub("%","",pxdx$EXACT.WORKLOAD))
pxdx.count<-pxdx[,c("HMS_PIID","HMS_POID","PHYS_FAC_COUNT")]

#if pxdx doesnt have org npi, need to read orgs file and get it from there
#merge it into the pxdx table
idx<-grep("NPI",colnames(pxdx))
if(length(idx) == 0 ) {
 orgs<-read.table("organizations.txt",header=T,sep="\t",
 as.is=T,quote="",comment.char="",fill=T,
 colClasses=c(ZIP="character",ZIP4="character"),na.strings="")
 
 #if TERR rank is found, use it to overwrite the NATL rank and delete TERR
 #name of the column stays as NATL, even thought it is actuall a TERR rank
 terr.rank.col<-grep("TERR",colnames(orgs))
 if(length(terr.rank.col) > 0) {
  orgs.terr.rank<-orgs[,c("HMS_POID",colnames(orgs)[terr.rank.col])]
  natl.rank.col<-grep("NATL",colnames(orgs))
  orgs[,natl.rank.col]<-orgs[,terr.rank.col]
  orgs<-orgs[,-terr.rank.col]
 }

 #reorder columns for a new orgs view and output
 orgs.new<-orgs
 rank.col<-grep("RANK",colnames(orgs.new))
 rank.col.name<-colnames(orgs.new)[rank.col]
 count.col<-grep("TOTAL",colnames(orgs.new))
 count.col.name<-colnames(orgs.new)[count.col]
 wantcols<-c("HMS_POID","NPI","ORGNAME","ORGTYPE","ADDRESS1","CITY",
 "STATE","ZIP","PHONE1","FAX1",count.col.name,rank.col.name)
 #print(wantcols)
 orgs.new<-orgs.new[,wantcols]
 orgs.new.st<-dostar(orgs.new)
 write.table(orgs.new.st,file="orgs_view.txt",col.names=F,row.names=F,
 quote=F,sep="\t",na="")
 #write.table(orgs.new.st,file="orgs_view_wh.txt",col.names=T,row.names=F,
 #quote=F,sep="\t",na="")
 
 orgs<-orgs[,c("HMS_POID","NPI")]
 pxdx<-merge(pxdx,orgs,by.x="HMS_POID",by.y="HMS_POID")
}

#replace the indiv natl rank in the pxdx data with indiv terr rank if exists
if(exists("indivs.terr.rank")) {
 pxdx<-merge(pxdx,indivs.terr.rank,by="HMS_PIID")
 pxdx[,"PHYS_NATL_RANK"]<-pxdx[,colnames(indivs.terr.rank)[2]]
 iremove<-grep(colnames(indivs.terr.rank)[2],colnames(pxdx))
 pxdx<-pxdx[,-iremove]
}
#replace the fac natl rank in the pxdx data with fac terr rank if exists
if(exists("orgs.terr.rank")) {
 pxdx<-merge(pxdx,orgs.terr.rank,by="HMS_POID")
 pxdx[,"FAC_NATL_RANK"]<-pxdx[,colnames(orgs.terr.rank)[2]]
 iremove<-grep(colnames(orgs.terr.rank)[2],colnames(pxdx))
 pxdx<-pxdx[,-iremove]
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

#cant do phys count any more due to starring coming in
#phys.count<-tapply(pxdx$PHYS_FAC_COUNT,pxdx$HMS_PIID,sum,na.rm=T)
#pxdx<-merge(pxdx,phys.count,by.x="HMS_PIID",by.y=0)
#colnames(pxdx)[ncol(pxdx)]<-"Phys.Total"
#calc.workload<-signif(pxdx$PHYS_FAC_COUNT/pxdx$Phys.Total,3)
#pxdx<-cbind(pxdx,calc.workload)
cutoff<-seq(0.1,0.3,0.05)
for(cut in cutoff)
{
 cname<-paste("workload",100*cut,sep="")
 work.flag<-rep.int(0,nrow(pxdx))
 work.flag[which(pxdx$EXACT.WORKLOAD >= 100*cut)]<-1
 pxdx<-cbind(pxdx,work.flag)
 colnames(pxdx)[ncol(pxdx)]<-cname 
}

#phys.max.workload<-tapply(pxdx$calc.workload,pxdx$HMS_PIID,max,na.rm=T)
phys.max.workload<-tapply(pxdx$EXACT.WORKLOAD,pxdx$HMS_PIID,max,na.rm=T)
workload.sums<-rowsum(pxdx[,c("workload10","workload15","workload20",
 "workload25","workload30")],pxdx$HMS_PIID,na.rm=T)
colnames(workload.sums)<-c("work10","work15","work20", "work25","work30")
pxdx<-merge(pxdx,phys.max.workload,by.x="HMS_PIID",by.y=0)
colnames(pxdx)[ncol(pxdx)]<-"Max.workload"
pxdx<-merge(pxdx,workload.sums,by.x="HMS_PIID",by.y=0)


pxdx.forexport<-merge(pxdx,indivs,by.x="HMS_PIID",by.y="HMS_PIID")
wantc<-c("HMS_PIID","HMS_POID","NPI.x","FIRST.y","LAST.y","SUFFIX.y","CRED.y",
"HMS_SPEC1.y","HMS_SPEC2.y","ADDRESS1.y","CITY.y","STATE.y","ZIP.y",
"PHONE1","FAX","ORGNAME","ORGTYPE","CITY.x","STATE.x","PHYS_NATL_RANK.y",
"FAC_NATL_RANK","PHYS_FAC_RANK","EXACT.WORKLOAD","WORKLOAD",
"Max.workload","work30","work25","work20","work15","work10")
pxdx.forexport<-pxdx.forexport[,wantc]
pxdx.forexport$EXACT.WORKLOAD<-trunc(pxdx.forexport$EXACT.WORKLOAD/10)

#merge in the counts and put in correct order
havecols<-colnames(pxdx.forexport)
pxdx.forexport<-merge(pxdx.forexport,pxdx.count,by=c("HMS_PIID","HMS_POID"))
newcols<-NULL
for (col in havecols)
{
 if(col == "PHYS_FAC_RANK") {
  #insert the count column
  newcols<-c(newcols,"PHYS_FAC_COUNT")
  newcols<-c(newcols,col)
 } else {
  newcols<-c(newcols,col)
 }
}
pxdx.forexport<-pxdx.forexport[,newcols]
#do star only if counts colum is numeric
if(is.numeric(pxdx.forexport$PHYS_FAC_COUNT)) {
 pxdx.forexport.st<-dostar(pxdx.forexport)
} else {
 pxdx.forexport.st<-pxdx.forexport
}
write.table(pxdx.forexport.st,file="pxdx_view.txt",row.names=F,col.names=F,
sep="\t",quote=F,na="")
#write.table(pxdx.forexport.st,file="pxdx_view_wh.txt",row.names=F,col.names=T,
#sep="\t",quote=F,na="")

#find poid with max workload for each piid
pxdx.formaxpoid<-pxdx[,c("HMS_PIID","HMS_POID","EXACT.WORKLOAD",
 "Max.workload")]
idx<-which(pxdx.formaxpoid$EXACT.WORKLOAD==pxdx.formaxpoid$Max.workload)
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
print(dim(indivs.view))
print(dim(maxworkload.wname))
indivs.view<-merge(indivs.view,maxworkload.wname,
by.x="HMS_PIID",by.y="HMS_PIID")
print(dim(indivs.view))
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

#convert Max.workload to range
brks<-c(-Inf,10,25,50,Inf)
mxwrk.range<-cut(indivs.view2$"Max.workload",breaks=brks,labels=c("<10%","10-25%","25-50%",">50%"))
mxwrk.int<-trunc(indivs.view2$"Max.workload"/10)
indivs.view2$Max.workload<-mxwrk.range
indivs.view2<-cbind(indivs.view2,mxwrk.int)

#now bring in the count and reorder the columns
havecols<-colnames(indivs.view2)
indivs.view2<-merge(indivs.view2,indivs.count,by="HMS_PIID")
newcols<-NULL
for (col in havecols)
{
 if(col == "PHYS_NATL_RANK.y") {
  #insert the count column
  newcols<-c(newcols,"COUNT")
  newcols<-c(newcols,col)
 } else {
  newcols<-c(newcols,col)
 }
}
indivs.view2<-indivs.view2[,newcols]
indivs.view2.st<-dostar(indivs.view2)
#export
write.table(indivs.view2.st,file="indivs_view.txt",
row.names=F,col.names=F,quote=F,sep="\t",na="")
#write.table(indivs.view2.st,file="indivs_view_wh.txt",
#row.names=F,col.names=T,quote=F,sep="\t",na="")




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
#handle new or old db column name for the rank column
idx<-grep("GRP",colnames(network))
if(length(idx) > 0) {
 wantc3<-c(wantc3, "TERR_SOR_VALUE", "GRP1_VOLUME_NATL_RANK2", "PCT1")
} else {
 wantc3<-c(wantc3, "TERR_SOR_VALUE", "Dx_VOLUME_NATL_RANK2", "PCT1")
}
network2<-network[,wantc3]
network2<-merge(network2,maxworkload.wnameplus,
by.x="HMS_PIID2",by.y="HMS_PIID",all.x=T)

#convert Max.workload to range
mxwrk.range<-cut(network2$"Max.workload",breaks=brks,labels=c("<10%","10-25%","25-50%",">50%"))
network2$Max.workload<-mxwrk.range


#reorder col1 and col2
cols<-colnames(network2)
cols2<-cols[c(2,1,3:length(cols))]
network2<-network2[,cols2]

write.table(network2,file="connected_physicians_view.txt",
row.names=F,col.names=F,sep="\t",na="",quote=F)
#write.table(network2,file="connected_physicians_view_wh.txt",
#row.names=F,col.names=T,sep="\t",na="",quote=F)







