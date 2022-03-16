#specify the old (standard process) directory here
olddir<-"olddir"
#specify the new (aggregation process) directory here
newdir<-"newdir"


old.linksf<-paste(olddir,"links.txt",sep="/")
new.linksf<-paste(newdir,"links.txt",sep="/")
old.denomf<-paste(olddir,"denom_fordelivery.txt",sep="/")
new.denomf<-paste(newdir,"denom_fordelivery.txt",sep="/")
old.rankedf<-paste(olddir,"rankeddenom.txt",sep="/")
new.rankedf<-paste(newdir,"rankeddenom.txt",sep="/")

old.links<-read.table(old.linksf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.links<-read.table(new.linksf,sep="\t",as.is=T,quote="",comment.char="",header=T)
old.denom<-read.table(old.denomf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.denom<-read.table(new.denomf,sep="\t",as.is=T,quote="",comment.char="",header=T)
old.ranked<-read.table(old.rankedf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.ranked<-read.table(new.rankedf,sep="\t",as.is=T,quote="",comment.char="",header=T)


###when comparing two new DB types, no need to force rename - changing HMS_PIID reference later
#colnames(old.links)[2]<-("COUNT")
#colnames(new.links)[2]<-("COUNT")
#colnames(new.denom)[1]<-("HMS_PIID")
#colnames(old.denom)[3]<-("NumConnEnt")
#colnames(old.denom)[1]<-("HMS_PIID")
#colnames(new.denom)[3]<-("NumConnEnt")
#colnames(new.ranked)[1]<-("HMS_PIID")
#colnames(old.ranked)[1]<-("HMS_PIID")


###switch order of PIIDs - no longer needed
#z <- data.frame(do.call(rbind, strsplit(as.vector(new.links$VAR1),split = ":")))
#names(z)<-c("VAR1","VAR2")
#new.fix.link<-paste(z$VAR2,":",z$VAR1, sep="")
#new.links2<-cbind(new.fix.link,new.links[,c(2,3)])
#new.links<-new.links2
#colnames(new.links)[1]<-("VAR1")


cat("record count comparisons\n")
old.link.rows<-nrow(old.links)
old.denom.rows<-nrow(old.denom)
new.link.rows<-nrow(new.links)
new.denom.rows<-nrow(new.denom)

link.pct.diff<-signif(100*(new.link.rows-old.link.rows)/old.link.rows,2)
denom.pct.diff<-signif(100*(new.denom.rows-old.denom.rows)/old.denom.rows,2)

cat("file\tstd_process\taggr_process\tpctchange\n")
cat("links\t",old.link.rows,"\t",new.link.rows,"\t",link.pct.diff,"\n")
cat("denom\t",old.denom.rows,"\t",new.denom.rows,"\t",denom.pct.diff,"\n")

co.denom<-merge(old.denom,new.denom,by="HMS_ID",all=T)
co.links<-merge(old.links,new.links,by="VAR1",all=T)
co.ranked<-merge(old.ranked,new.ranked,by="HMS_ID",all=T)


##Net loss and gain
# num links and denom only in old/new
### denom
denom.loss <- subset(co.denom, is.na(Grp1Rank.y))
denom.gain <- subset(co.denom, is.na(Grp1Rank.x))

denom.l.count <- paste("count of dropped IDs = ",nrow(denom.loss))
denom.g.count <- paste("count of net new IDs = ",nrow(denom.gain))
denom.l.pct1 <- (nrow(denom.loss)/old.denom.rows)*100
denom.g.pct1 <- (nrow(denom.gain)/old.denom.rows)*100

denom.l.pct <- paste("percent of dropped IDs = ",denom.l.pct1)
denom.g.pct <- paste("percent of net new IDs = ",denom.g.pct1)

### links
links.loss <- subset(co.links, is.na(COUNT.y))
links.gain <- subset(co.links, is.na(COUNT.x))

links.l.count <- paste("count of dropped links = ",nrow(links.loss))
links.g.count <- paste("count of net new links = ",nrow(links.gain))
links.l.pct1<- (nrow(links.loss)/old.link.rows)*100
links.g.pct1<- (nrow(links.gain)/old.link.rows)*100

links.l.pct <- paste("percent of dropped links = ",links.l.pct1)
links.g.pct <- paste("percent of net new links = ",links.g.pct1)


### 11 by 11s that includes dropped and gained records:

denom.table<-(table(co.denom[,2],co.denom[,4]))
print("11 by 11 table for denom ranks")
print(denom.table)

rank.table<-(table(co.links[,3],co.links[,5]))
print("11 by 11 table for SOR vals")
print(rank.table)



#subset to only records in both old and new to get % good

for(i in c(2,3,4,5))


{

 idx<-which(is.na(co.ranked[,i]))
 if(length(idx) > 0) {
   co.ranked[idx,i]<-0.1
 }
 }
 
 for(i in c(2,3,4,5))
 {
 idx<-which(is.na(co.links[,i]))
 if(length(idx) > 0) {
   co.links[idx,i]<-0.1
 }
}
 

 




###
####calculate % good - for Denom should be change of less than 10 or within 10% of old value

diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
log10(1.00001),log10(1.1),log10(2),Inf)
dx.ranked.count.diff<-log10(co.ranked$Grp1Cnt.x/co.ranked$Grp1Cnt.y)
dx.ranked.binned<-cut(dx.ranked.count.diff,breaks=diff.breaks,labels=c(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("dx ranked denom pat count change distribution\n")

dbin.label <- paste(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr")
dx.bin.ranked<-print(table(dx.ranked.binned),include.colnames=T)

ranked.diff<-log10(co.ranked$Grp1Cnt.x/co.ranked$Grp1Cnt.y)
ranked.diff2<-abs(co.ranked$Grp1Cnt.x-co.ranked$Grp1Cnt.y)
i1<-which(ranked.diff2 <= 5)
i2<-which((ranked.diff < log10(1.1)) & (ranked.diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))

dx.ranked.good.10<-100*(length(i)/length(ranked.diff2))
print.dx.10<-paste("dx denom good 10% = ",dx.ranked.good.10)

i1<-which(ranked.diff2 <= 10)
i2<-which((ranked.diff < log10(1.25)) & (ranked.diff > log10(1/1.25)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))

dx.ranked.good.25<-100*(length(i)/length(ranked.diff2))
print.dx.25<-paste("dx denom good 25% = ",dx.ranked.good.25)



#calculate % good - for links should be change of less than 2 or within 10% of old value

links.diff<-log10(co.links$COUNT.x/co.links$COUNT.y)
links.diff2<-abs(co.links$COUNT.x-co.links$COUNT.y)
i1<-which(links.diff2 <= 2)
i2<-which((links.diff < log10(1.1)) & (links.diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
links.good<-100*(length(i)/length(links.diff2))
links.good.pct<-paste("percent links good = ",links.good)

links.binned<-cut(links.diff,breaks=diff.breaks,labels=c(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
bin.links <- table(links.binned)
lbin.label <- paste(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr")


#### ------------------------ OUTPUT CHURN ----------
## combine results into one DF for export


cat("Churn results","\n", print.dx.10, "\n", print.dx.25, "\n", "denom change distr", "\n", dbin.label, "\n", dx.bin.ranked, "\n", 
"link change distr", "\n", links.good.pct, "\n", lbin.label,"\n", bin.links, "\n", links.l.count, "\n", 
links.l.pct, "\n", links.g.count, "\n", links.g.pct, "\n", denom.l.count, "\n", denom.l.pct, "\n", denom.g.count, 
"\n", denom.g.pct,file="Dx_churn_statistics.txt",sep="\n")



# 11 by 11s - only for records in both old and new
#rank.table<-(table(co.links[,3],co.links[,5]))
#print("11 by 11 table for SOR vals")
#print(rank.table)

#denom.table<-(table(co.denom[,2],co.denom[,4]))
#print("11 by 11 table for denom ranks")
#print(denom.table)


##### ------------------------------------------------ plots -------
# plots for Links


##
links.minval<-min(c(co.links$COUNT.x,co.links$COUNT.y))
links.lminval<-log10(links.minval)
links.maxval<-max(c(co.links$COUNT.x,co.links$COUNT.y))
links.lmaxval<-log10(links.maxval)


pdf("comparisons.pdf",onefile=T)
links.max<-max(max(co.links$COUNT.x),max(co.links$COUNT.y))
plot(co.links$COUNT.x,co.links$COUNT.y,xlab="Old",
ylab="New",main="links",pch=4,cex=.5,
xlim=c(.1,links.max),ylim=c(0.1,links.max),log="xy")
lines(c(0.1,links.max),c(0.1,links.max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co.links$COUNT.x),log10(co.links$COUNT.y),colramp = Lab.palette,
xlab="Old",ylab="New",main="Links",xlim=c(links.lminval,links.lmaxval),ylim=c(links.lminval,links.lmaxval))
lines(c(links.lminval,links.lmaxval),c(links.lminval,links.lmaxval),lwd=3,col="red")


#min/max for denom # connections

#min/max for ranked denom # of patients

ranked.minval<-min(c(co.ranked$Grp1Cnt.x,co.ranked$Grp1Cnt.y))
ranked.lminval<-log10(ranked.minval)
ranked.maxval<-max(c(co.ranked$Grp1Cnt.x,co.ranked$Grp1Cnt.y))
ranked.lmaxval<-log10(ranked.maxval)

#Plots for Ranked denom based on num of dx patients

ranked.max<-max(max(co.ranked$Grp1Cnt.x),max(co.ranked$Grp1Cnt.y))
plot(co.ranked$Grp1Cnt.x,co.ranked$Grp1Cnt.y,xlab="Old",
ylab="New",main="Denom Patients",pch=4,cex=.5,
xlim=c(0.1,1000),ylim=c(0.1,1000),log="xy")
lines(c(0.1,1000),c(0.1,1000),lwd=3,col="red")
# heat plot
# denom Dx connections
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co.ranked$Grp1Cnt.x),log10(co.ranked$Grp1Cnt.y),colramp = Lab.palette,
xlab="Old",ylab="New",main="denom patients",xlim=c(0.1,1),ylim=c(0.1,1))
lines(c(0.1,1),c(0.1,1),lwd=3,col="red")



dev.off()


