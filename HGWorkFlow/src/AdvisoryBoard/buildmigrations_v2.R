#read poidvolcomp.txt and try to figure out migrations
#this process is independent of the migrations MF team produces
#might be some overlap that needs to be deduped
#assume this runs after MF build
#so new and old Organizations.tab files are available

#read inputs from directory above
par<-read.table("../compinput.txt",header=T,sep="\t",as.is=T)
prevMF<-subset(par,Parameter=="PrevMF")$Value
currMF<-subset(par,Parameter=="CurrMF")$Value

#figure out what setting this is from directory name
ldir<-getwd()
sett<-""
if(length(grep("IP",ldir))) {
 sett<-"IP"
} else if(length(grep("OP",ldir))) {
 sett<-"OP"
} else if(length(grep("Freestanding",ldir))) {
 sett<-"Freestanding"
} else if(length(grep("OfficeASC",ldir))) {
 sett<-"OfficeASC"
} else if(length(grep("SNF",ldir))) {
 sett<-"SNF"
}
if(sett == "") {
 cat("couldnt figure out setting, exiting\n")
 quit()
} else {
 cat("setting is = |",sett,"|\n")
}


#read the old and new MF org tables
old.orgs<-read.table(file=prevMF,header=T,sep="\t",as.is=T,
quote="",comment.char="")
new.orgs<-read.table(file=currMF,header=T,sep="\t",as.is=T,
quote="",comment.char="")

#read the poidvolcomp.txt file
comb<-read.table("poidvolcomp.txt",header=T,sep="\t",as.is=T,
quote="",comment.char="",fill=T)

if(sett == "Freestanding") {
 #note freestanding-specific definition of drop and add
 dropped<-subset(comb,lograt.ClaimCount < -1.0,select=c(HMS_POID,PrevTotal))
 added<-subset(comb,lograt.ClaimCount > 1,select=c(HMS_POID,CurrTotal))
} else {
 dropped<-subset(comb,PrevTotal > 0.5 & CurrTotal < 0.5,select=c(HMS_POID,PrevTotal))
 added<-subset(comb,PrevTotal < 0.5 & CurrTotal > 0.5,select=c(HMS_POID,CurrTotal))
}

#check the size of dropped to decide whether to proceed
if(nrow(dropped) == 0) {
 print("no POIDs dropped, please confirm using graph")
 quit()
}

wantcols<-c("HMS_POID", "ORGNAME", "ADDRESS1", "ADDRESS2", "CITY",
"STATE", "ZIP", "FACTYPE")

old.orgs<-old.orgs[,wantcols]
new.orgs<-new.orgs[,wantcols]

dropped<-merge(dropped,old.orgs,by.x="HMS_POID",by.y="HMS_POID",all.x=T)
added<-merge(added,new.orgs,by.x="HMS_POID",by.y="HMS_POID",all.x=T)

#find closest edit distance orgname/city combo in added
#for every org in dropped
closest.poid<-rep("NULL",nrow(dropped))
closest.dist<-rep.int(10000,nrow(dropped))
closest<-data.frame(cbind(closest.poid,closest.dist),stringsAsFactors=F)

for(i in 1:nrow(dropped))
{
 #subset added to same state
 added.state<-subset(added,STATE==dropped[i,"STATE"])
 dvec<-as.vector(adist(paste(dropped[i,"ORGNAME"],dropped[i,"ADDRESS1"],dropped[i,"CITY"],sep=""), paste(added.state$ORGNAME,added.state$ADDRESS1,added.state$CITY,sep="")))
 #print(dvec)
 sorted.d.idx<-sort.list(dvec)
 #pick the closest match
 closest[i,1]<-added.state[sorted.d.idx[1],"HMS_POID"]
 s1<-paste(dropped[i,"ORGNAME"],dropped[i,"ADDRESS1"],dropped[i,"CITY"],sep="")
 i2<-sorted.d.idx[1]
 s2<-paste(added.state[i2,"ORGNAME"],added.state[i2,"ADDRESS1"],added.state[i2,"CITY"],sep="")
 l1<-nchar(s1)
 l2<-nchar(s2)
 minchar<-min(l1,l2)
 score<-signif(dvec[sorted.d.idx[1]]/minchar,2)
 closest[i,2]<-score
}

dropped<-cbind(dropped,closest)
#merge in CurrTotal
dropped<-merge(dropped,added,by.x="closest.poid",by.y="HMS_POID",all.x=T)
colorder<-c(1:ncol(dropped))
colorder[1]<-2
colorder[2]<-1
dropped<-dropped[,colorder]
colnames(dropped)[1:2]<-c("Prev_POID","Curr_POID")

write.table(dropped,file="migrations_candidates.txt",
quote=F,sep="\t",row.names=F,col.names=T)
