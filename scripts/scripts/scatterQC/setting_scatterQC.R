args = commandArgs(trailingOnly=TRUE)

oldpath<-args[1]
newpath<-args[2]

#specify the old (standard process) projection file here
old<-read.table(oldpath, sep="\t",as.is=T,quote="",comment.char="",header=T)
#specify the new projection file here
new<-read.table(newpath,sep="\t",as.is=T,quote="",comment.char="",header=T)


#keep only PIID, POID, and PIID@POID counts - grep for PractFac to account for various headers

i.old<-grep("PractFac",colnames(old))
i.new<-grep("PractFac",colnames(new))

colcount.old<-ncol(old)
colcount.new<-ncol(new)

if (colcount.old > 3 ){
	wantcols.old<-c("HMS_PIID","HMS_POID",colnames(old)[i.old])
	old<-old[wantcols.old]

}

if (colcount.new > 3) {
	wantcols.new<-c("HMS_PIID","HMS_POID",colnames(new)[i.new])
	new<-new[wantcols.new]

}

#compare record counts
cat("record count comparisons\n")
old.rows<-nrow(old)
new.rows<-nrow(new)

pct.diff<-signif(100*(new.rows-old.rows)/old.rows,2)

cat("file\tstd_process\taggr_process\tpctchange\n")
cat("indiv\t",old.rows,"\t",new.rows,"\t",pct.diff,"\n")

#merge for volume analysis
co<-merge(old,new,by=c("HMS_PIID","HMS_POID"),all=T)

for(i in c(3,4))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
 
}


#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
log10(1.00001),log10(1.1),log10(2),Inf)
diff<-log10(co[,3]/co[,4])
binned<-cut(diff,breaks=diff.breaks,labels=c(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("change distribution\n")
print(table(binned))
diff2<-abs(co[,3]-co[,4])
i1<-which(diff2 <= 10)
i2<-which((diff < log10(1.1)) & (diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent good = ",pct.good,"\n")

bad<-co[-i,]
write.table(bad,file="bad_records.txt",row.names=F,col.names=T,quote=F,sep="\t")

i1<-which(diff2 <= 5)
i2<-which((diff < log10(1.1)) & (diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent good 5 = ",pct.good,"\n")


#plot comparisons

pdf("comparisons.pdf",onefile=T)
max<-max(max(co[,3]),max(co[,4]))
min<-min(min(co[,3]),min(co[,4]))
lmax<-log10(max)
lmin<-log10(min)
plot(co[,3],co[,4],xlab="Old DB",
ylab="New DB",main="PractFac Compare",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co[,3]),log10(co[,4]),colramp = Lab.palette,
xlab="Old",ylab="New",main="PractFac Compare",xlim=c(lmin,lmax),ylim=c(lmin,lmax))
lines(c(lmin,lmax),c(lmin,lmax),lwd=3,col="red")



dev.off()


