#script to help select input piid universe for network filter script
#1) user-specifices indivs file from a pxdx; user also specifies the rank column
#2) user-specified INA Comb directory with a denom_for_delivery.txt
#3) user specifies a list of specialties wanted
#4) user specifies a list of indiv ranks to keep
#5) user specifics a list of zips to keep
#6) code does the filter of the indivs for zip, spec, rank, and estimates
# the number of rows in network file, and outputs the filtered version of
# the indivs file

#new as of 6.20.2014
#user has option to specify the pxdx file as well
#if this is specified, then a new approach is used for filtering:
#calculate exact workload for all piids at all orgs, filter orgs to zips of
#interst, sum workload, and if piids have > 0.25 sum of workload, include
#along with all piids with addr1 zip in zips of interest from indivs file
#and then make filtered piid list

#new as of 9/11/2015
#works for piid or poid list creation, to handle new network types
#PxDx file and specialties file don't apply to orgs case, leave out row, 
# or leave value blank

#read the parameters file
par<-read.table(file="idselectioninputs.txt",header=T,sep="\t",as.is=T,fill=T)

#see if pxdx file specified, read it if it is
pxdxf<-""
if(length(grep("PxDxFile",par$Parameter)) == 1) {
 pxdxf<-subset(par,Parameter=="PxDxFile")$Value
}
if(pxdxf != "") {
 pxdx<-read.table(pxdxf,header=T,sep="\t",quote="",comment.char="",as.is=T,fill=T,colClasses=c(ZIP="character",ZIP4="character"),na.strings="")
 
 #check to make sure only 1 claim/pat/proc count column, and calc exact
 #workload if that is true
 i1<-grep("PATIENTS",colnames(pxdx))
 i2<-grep("CLAIM",colnames(pxdx))
 i3<-grep("PROC",colnames(pxdx))
 i<-union(i1,i2)
 i<-union(i,i3)
 if(length(i) == 1) {
   i.piid<-grep("HMS_PIID",colnames(pxdx))
   i.poid<-grep("HMS_POID",colnames(pxdx))
   i<-union(i.poid,i)
   i<-union(i.piid,i)
   #add the zip columns
   i.zip<-grep("ZIP",colnames(pxdx))
   i<-union(i,i.zip)
   pxdx.forfilt<-pxdx[,i]
   indiv.tot<-tapply(pxdx.forfilt[,3],pxdx.forfilt$HMS_PIID,sum)
   pxdx.forfilt<-merge(pxdx.forfilt,indiv.tot,by.x="HMS_PIID",by.y=0)
   wrkld<-pxdx.forfilt[,3]/pxdx.forfilt[,6]
   pxdx.forfilt<-cbind(pxdx.forfilt,wrkld)
 } else {
  #can do the min-workload criterion using pxdx only if single bucket pxdx
  #if more than 1 bucket found, have to exit
  print("looks like more than 1 bucket in the pxdx file, cant handle, exiting\n")
  print(colnames(pxdx)[i])
  quit()
 }
}

#figure out if indiv or org is being filtered to produce list
idf<-""
if(length(grep("IndivsFile",par$Parameter)) == 1) {
 idf<-subset(par,Parameter=="IndivsFile")$Value
}
if(length(grep("OrgsFile",par$Parameter)) == 1) {
 idf<-subset(par,Parameter=="OrgsFile")$Value
}
if(idf != "") {
 #read the id file
 iddata<-read.table(idf,header=T,sep="\t",quote="",comment.char="",as.is=T,fill=T,colClasses=c(ZIP="character",ZIP4="character"),na.strings="")
}

#read the specialty list
specfile<-subset(par,Parameter=="SpecialtiesFile")$Value
if(specfile != "") {
 specs<-read.table(specfile,header=F,sep="\t")
}

#read the zips
zipfile<-subset(par,Parameter=="ZipsFile")$Value
if(zipfile != "") {
 zips<-read.table(zipfile,header=F,sep="\t",colClasses="character")
}

#figure out the rank column to use for filter, and min rank value
#if min rank is blank, use 1 as min
rankcol<-subset(par,Parameter=="RankColumn")$Value
minrank<-subset(par,Parameter=="MinimumRankToKeep")$Value
if(minrank == "") {
 minrank <- 1
} 
minrank<-as.numeric(minrank)

iddata2<-iddata

#check which data frames exist
dframes<-ls()
print(dframes)

#apply the zip filter
if(length(grep("zips",dframes)) > 0) {
 iddata2<-subset(iddata2,ZIP %in% zips[,1])
}

#now add in any additional piids who are outside zip, but have more then 25%
#total workload at orgs in the zips of interest
#assuming this is a piid filter and pxdx has been speficied
if(nchar(pxdxf) > 0) {
 filt.pxdx<-subset(pxdx.forfilt,(ZIP %in% zips[,1]))
 geo.sum.wrkld<-tapply(filt.pxdx$wrkld,filt.pxdx$HMS_PIID,sum)
 idx<-which(geo.sum.wrkld > 0.25)
 affil.piids<-names(geo.sum.wrkld)[idx]
 net.new.piids<-setdiff(affil.piids,iddata2$HMS_PIID)
 net.new.iddata2<-subset(iddata,HMS_PIID %in% net.new.piids)
 iddata2<-rbind(iddata2,net.new.iddata2)
}

#apply the min rank filter
if(minrank > 1) {
 iddata2<-subset(iddata2,iddata2[,rankcol] >= minrank)
}

#apply the specialty filter
if(length(grep("specs",dframes)) > 0) {
 iddata2<-subset(iddata2,HMS_SPEC1 %in% specs[,1])
}

##writeout the idlist
write.table(iddata2,file="idlist.txt",row.names=F,col.names=T,quote=F,sep="\t",na="")





