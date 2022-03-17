#specify the old (standard process) directory here
olddir<-"/vol/cs/clientprojects/VGM/2015_05_27_Tycon_Medical_Inc_Power_Wheelchairs/Power_Wheelchairs/Projections/Home"
#specify the new (aggregation process) directory here
newdir<-"/vol/cs/clientprojects/VGM/2015_06_25_Tycon_Power_Wheelchairs/Power_Wheelchairs/Projections/Home"


old.projf<-paste(olddir,"home_projection.txt",sep="/")
new.projf<-paste(newdir,"home_projection.txt",sep="/")

old.proj<-read.table(old.projf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.proj<-read.table(new.projf,sep="\t",as.is=T,quote="",comment.char="",header=T)


cat("record count comparisons\n")

old.rows<-nrow(old.proj)
new.rows<-nrow(new.proj)
pct.diff<-signif(100*(new.rows-old.rows)/old.rows,2)

cat("file\tstd_process\taggr_process\tpctchange\n")
cat("change\t",old.rows,"\t",new.rows,"\t",pct.diff,"\n")



co<-merge(old.proj,new.proj,by=c("HMS_PIID","HMS_POID"),all=T)

for(i in c(3,4,5,6,7,8))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
 
}

#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
log10(1.00001),log10(1.1),log10(2),Inf)

#pract @ facility counts
diff.practfac<-log10(co[,3]/co[,6])
binned.practfac<-cut(diff.practfac,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("change distribution\n")
print(table(binned.practfac))
diff2<-abs(co[,3]-co[,6])
i1<-which(diff.practfac<= 10)
i2<-which((diff.practfac < log10(1.1)) & (diff.practfac > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent pract@fac good = ",pct.good,"\n")


pdf("comparisons.pdf",onefile=T)


max<-max(max(co[,3]),max(co[,6]))
plot(co[,3],co[,6],xlab="old",
ylab="new",main="pract@fac",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")

#pract counts
diff.pract<-log10(co[,4]/co[,7])
binned.pract<-cut(diff.pract,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("pract change distribution\n")
print(table(binned.pract))
diff2<-abs(co[,4]-co[,7])
i1<-which(diff.pract<= 10)
i2<-which((diff.pract < log10(1.1)) & (diff.pract > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent pract good = ",pct.good,"\n")



max<-max(max(co[,4]),max(co[,7]))
plot(co[,4],co[,7],xlab="old",
ylab="new",main="pract national",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")

#Fac counts
diff.fac<-log10(co[,5]/co[,8])
binned.fac<-cut(diff.fac,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("fac change distribution\n")
print(table(binned.fac))
diff2<-abs(co[,5]-co[,8])
i1<-which(diff.fac<= 10)
i2<-which((diff.fac < log10(1.1)) & (diff.fac > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent fac good = ",pct.good,"\n")



max<-max(max(co[,5]),max(co[,8]))
plot(co[,5],co[,8],xlab="old",
ylab="new",main="fac national",pch=4,cex=.5,
xlim=c(.1,max),ylim=c(0.1,max),log="xy")
lines(c(0.1,max),c(0.1,max),lwd=3,col="red")

dev.off()


