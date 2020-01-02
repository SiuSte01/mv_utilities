#read poidvolcomp.txt and do the AB check on the migration file
#produce file that has these columns
#old_poid
#new_poid
#old_poid_old_vol
#old_poid_new_vol
#new_poid_old_vol
#new_poid_new_vol

#read inputs from directory above
par<-read.table("../compinput.txt",header=T,sep="\t",as.is=T)
prevMF<-subset(par,Parameter=="PrevMF")$Value

#read the old MF org table
old.orgs<-read.table(file=prevMF,header=T,sep="\t",as.is=T,
quote="",comment.char="")

#read the poidvolcomp.txt file
comb<-read.table("poidvolcomp.txt",header=T,sep="\t",as.is=T,
quote="",comment.char="",fill=T)

#produce the previous and current lists from comb
prev.poidtot<-comb[,c("HMS_POID","PrevTotal")]
prev.poidtot<-subset(prev.poidtot,PrevTotal > 0.5)
curr.poidtot<-comb[,c("HMS_POID","CurrTotal")]
curr.poidtot<-subset(curr.poidtot,CurrTotal > 0.5)

dropped<-subset(comb,PrevTotal > 0.5 & CurrTotal < 0.5,select=c(HMS_POID))
wantcols<-c("HMS_POID", "ORGNAME", "CITY", "STATE" )
old.orgs<-old.orgs[,wantcols]
dropped<-merge(dropped,old.orgs,by="HMS_POID",all.x=T)


#read migrations
migs<-read.table("final_migrations.txt",header=T,sep="\t",as.is=T)

migs<-merge(dropped,migs,by.x="HMS_POID",by.y="Old_Value",all.x=T)

migs<-merge(migs,prev.poidtot,by="HMS_POID",all.x=T)
colnames(migs)[ncol(migs)]<-"OldPoid_OldVolume"

migs<-merge(migs,curr.poidtot,by.x="HMS_POID",all.x=T)
colnames(migs)[ncol(migs)]<-"OldPoid_NewVolume"

migs<-merge(migs,prev.poidtot,by.x="New_Value",by.y="HMS_POID",all.x=T)
colnames(migs)[ncol(migs)]<-"NewPoid_OldVolume"

migs<-merge(migs,curr.poidtot,by.x="New_Value",by.y="HMS_POID",all.x=T)
colnames(migs)[ncol(migs)]<-"NewPoid_NewVolume"

idx<-sort.list(migs$OldPoid_OldVolume,decr=T)
migs<-migs[idx,]
i1<-grep("HMS_POID",colnames(migs))
colnames(migs)[i1]<-"OLD_POID"
i2<-grep("New_Value",colnames(migs))
colnames(migs)[i2]<-"NEW_POID"
wantcols<-c(2,1,3:ncol(migs))

write.table(migs[,wantcols],file="migrations_checked.txt",row.names=F,
col.names=T,na="",quote=F,sep="\t")
