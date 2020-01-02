if(file.exists("individuals_dx_filt.tab")) {
 indivs<-read.table("individuals_dx_filt.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("indivs_grp1_filtered.tab")) {
 #below version of file for the new db 
 indivs<-read.table("indivs_grp1_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
}

#check for indivs file for the px pxdx in a dx->px network
if(file.exists("individuals_px_filt.tab")) {
 indivs_px<-read.table("individuals_px_filt.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("indivs_grp2_filtered.tab")) {
 #check for indivs file for the grp2 pxdx in a 2-group network
 indivs_px<-read.table("indivs_grp2_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
}

if(file.exists("pxdxaffils_filtered.tab_exact")) {
 pxdx<-read.table("pxdxaffils_filtered.tab_exact",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("pxdxaffils_filtered.tab")) {
 pxdx<-read.table("pxdxaffils_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("affils_grp1_filtered.tab")) {
 pxdx<-read.table("affils_grp1_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
}

#check for affils file for the px pxdx in a dx->px network
if(file.exists("pxdxaffils_px_filtered.tab")) {
 pxdx_px<-read.table("pxdxaffils_px_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("affils_grp2_filtered.tab")) {
 pxdx_px<-read.table("affils_grp2_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
}

#check for orgs file
if(file.exists("pxdxorgs_filtered.tab")) {
 orgs<-read.table("pxdxorgs_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("orgs_grp1_filtered.tab")) {
 orgs<-read.table("orgs_grp1_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} 

#check for orgs file for the px pxdx in a dx->px network
if(file.exists("pxdxorgs_px_filtered.tab")) {
 orgs_px<-read.table("pxdxorgs_px_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} else if(file.exists("orgs_grp2_filtered.tab")) {
 orgs_px<-read.table("orgs_grp2_filtered.tab",header=T,sep="\t",
 quote="",comment.char="",as.is=T,colClasses=c(ZIP="character",ZIP4="character"), na.strings="")
} 


dostar<-function(d)
{
 idx1<-grep("CLAIMS",colnames(d))
 idx2<-grep("PATIENTS",colnames(d))
 idx3<-grep("PROCS",colnames(d))
 idx<-union(idx1,idx2)
 idx<-union(idx,idx3)
 for(i in idx)
 {
  low.idx<-which(d[,i]<11)
  if(length(low.idx) > 0) { 
    d[low.idx,i]<-"*"
  }
 }
 d
}

indivs.st<-dostar(indivs)

write.table(indivs.st,file="indivs_grp1_fordelivery.tab",col.names=T,
row.names=F,quote=F,sep="\t",na="")

if(exists("indivs_px")) {
 indivs_px.st<-dostar(indivs_px)
 write.table(indivs_px.st,file="indivs_grp2_fordelivery.tab",col.names=T,
 row.names=F,quote=F,sep="\t",na="")
}

if(exists("orgs")) {
 orgs.st<-dostar(orgs)
 write.table(orgs.st,file="orgs_grp1_fordelivery.tab",col.names=T,
 row.names=F,quote=F,sep="\t",na="")
}
if(exists("orgs_px")) {
 orgs_px.st<-dostar(orgs_px)
 write.table(orgs_px.st,file="orgs_grp2_fordelivery.tab",col.names=T,
 row.names=F,quote=F,sep="\t",na="")
}

if(exists("pxdx")) {
 pxdx.st<-dostar(pxdx)
 #write.table(pxdx.st,file="affils_fordelivery.tab",col.names=T,
 write.table(pxdx.st,file="affils_grp1_forbiltmore.tab",col.names=T,
 row.names=F,quote=F,sep="\t",na="")
}

if(exists("pxdx_px")) {
 pxdx_px.st<-dostar(pxdx_px)
 #write.table(pxdx_px.st,file="affils_px_fordelivery.tab",col.names=T,
 write.table(pxdx_px.st,file="affils_grp2_forbiltmore.tab",col.names=T,
 row.names=F,quote=F,sep="\t",na="")
}
