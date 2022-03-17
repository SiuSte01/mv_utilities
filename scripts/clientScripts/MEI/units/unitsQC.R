#link in units files

old.units<-read.table("/vol/datadev/Statistics/Projects/NewProjWorkFlow/InputDataFiles/DMECode_Median_Units.txt",sep="\t",as.is=T,quote="",comment.char="",header=T)
new.units<-read.table("UNITS_MEI.txt",sep="\t",as.is=T,quote="",comment.char="",header=T)
mix.units<-read.table("UNITS_analysis.txt",sep="\t",as.is=T,quote="",comment.char="",header=T)

colnames(new.units)[1]<-"CODE"
new.units1<-new.units[complete.cases(new.units),]
old.units1<-old.units[complete.cases(old.units),]

cat("record count comparisons\n")

old.rows<-nrow(old.units1)
new.rows<-nrow(new.units1)
pct.diff<-signif(100*(new.rows-old.rows)/old.rows,2)

cat("file\tstd_process\taggr_process\tpctchange\n")
cat("change\t",old.rows,"\t",new.rows,"\t",pct.diff,"\n")



co<-merge(old.units1,new.units1,by=c("CODE"),all=T)

for(i in c(2,3,4,5,6,7))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
 
}

#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
log10(1.00001),log10(1.1),log10(2),Inf)

#unit median changes
diff.units<-log10(co[,3]/co[,6])
binned.units<-cut(diff.units,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("median change distribution\n")
print(table(binned.units))
diff2<-abs(co[,3]-co[,6])
i1<-which(diff.units<= 1)
i2<-which((diff.units < log10(1.1)) & (diff.units > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent median good = ",pct.good,"\n")


pdf("comparisons.pdf",onefile=T)

#plot median values
max<-max(max(co[,3]),max(co[,6]))
lmax<-log10(max)
min<-min(min(co[,3]),min(co[,6]))
lmin<-min
plot(co[,3],co[,6],xlab="old",
ylab="new",main="median units",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co[,3]),log10(co[,6]),colramp = Lab.palette,
xlab="Old",ylab="New",main="Median units",xlim=c(lmin,lmax),ylim=c(lmin,lmax))
lines(c(lmin,lmax),c(lmin,lmax),lwd=3,col="red")

#mean counts
diff.mean<-log10(co[,2]/co[,5])
binned.mean<-cut(diff.mean,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("mean change distribution\n")
print(table(binned.mean))
diff2<-abs(co[,2]-co[,5])
i1<-which(diff.mean<= 1)
i2<-which((diff.mean < log10(1.1)) & (diff.mean > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent mean good = ",pct.good,"\n")




#plot mean units

max<-max(max(co[,2]),max(co[,5]))
lmax<-log10(max)
min<-min(min(co[,2]),min(co[,5]))
lmin<-min
plot(co[,2],co[,5],xlab="old",
ylab="new",main="mean units",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co[,2]),log10(co[,5]),colramp = Lab.palette,
xlab="Old",ylab="New",main="Mean units",xlim=c(lmin,lmax),ylim=c(lmin,lmax))
lines(c(lmin,lmax),c(lmin,lmax),lwd=3,col="red")

dev.off()

#export list of procs missing from new list
co.miss<-co[which(co$UNIT_mean.y==0.1),]
write.table(co.miss, "missing_codes.txt", sep="\t")


