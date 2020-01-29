#created the poid volume comparison graph after applying the final migrations

#read the poidvolcomp.txt file
comb<-read.table("poidvolcomp.txt",header=T,sep="\t",as.is=T,
quote="",comment.char="",fill=T)

#produce the previous and current lists from comb
prev.poidtot<-comb[,c("HMS_POID","PrevTotal")]
prev.poidtot<-subset(prev.poidtot,PrevTotal > 0.5)
curr.poidtot<-comb[,c("HMS_POID","CurrTotal")]
curr.poidtot<-subset(curr.poidtot,CurrTotal > 0.5)

#save the profile information
profile.data<-comb[,c("HMS_POID","ORG_NAME","STATE_CODE")]

#read the final migrations
mig<-read.table("final_migrations.txt",header=T,sep="\t",as.is=T)

#migrate the old totals, and aggregate in case of any collapsing
prev.poidtot<-merge(prev.poidtot,mig,by.x="HMS_POID",by.y="Old_Value",all.x=T)
idx<-which(is.na(prev.poidtot$New_Value))
if(length(idx) > 0) {
 prev.poidtot[idx,"New_Value"]<-prev.poidtot[idx,1]
}
prev.poidtot<-prev.poidtot[,c(3,2)]
colnames(prev.poidtot)[1]<-"HMS_POID"
prev2<-aggregate(PrevTotal~HMS_POID,data=prev.poidtot,sum,na.rm=T)

comb<-merge(curr.poidtot,prev2,by="HMS_POID",all=T)

for(i in c(2:3))
{
 idx1<-which(is.na(comb[,i]))
 idx2<-which(comb[,i]==0)
 idx<-union(idx1,idx2)
 if(length(idx) > 0) {
  comb[idx,i]<-0.1 
 }
}

lograt.ClaimCount<-signif(log10(comb$CurrTotal/comb$PrevTotal),3)
DeltaCount=comb$CurrTotal-comb$PrevTotal
comb<-cbind(comb,lograt.ClaimCount,DeltaCount)

#add back the saved profiles
comb<-merge(comb,profile.data,by="HMS_POID",all.x=T)
comb<-subset(comb,CurrTotal > 0.5 | PrevTotal > 0.5)
comb<-subset(comb,HMS_POID != "")

pdf("poidvolcomp_wmigr.pdf",onefile=T)
maxval<-max(max(comb$CurrTotal),max(comb$PrevTotal))         
minval<-min(min(comb$CurrTotal),min(comb$PrevTotal))         
print(minval)
print(maxval)
plot(CurrTotal~PrevTotal,data=comb,log="xy",pch=4,cex=.5,
ylab="Current",xlab="Previous",main="POID ClaimCount",xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=2,col="red")
dev.off()
