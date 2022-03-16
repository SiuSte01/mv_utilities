 #mkdir for QA
#cd into QA directory and 
#symlink the old result as follows:
#  ln -s  full_pathname_of_old_result   old.txt
#symlink the new result as follows:
# ln -s full_pathname_of_new_result   new.txt
#using symlinks we can run this code for all settings - IRF/LTAC/Etc
#  then run this R code:   R CMD BATCH --vanilla comp.R

feb<-read.table(".txt",header=T,sep="\t",as.is=T,quote="",
comment.char="")

new<-read.table("new.txt",header=T,sep="\t",as.is=T,quote="",
comment.char="")


row.old<-nrow(old)
row.new<-nrow(new)

cat("number of rows in old = ",row.old,"\n")
cat("number of rows in new = ",row.new,"\n")
cat("row count diff = ",((row.new-row.old)/row.old)*100,"\n")

co<-merge(feb,mar,by=c("code"),all=T)
for(i in c(2:3))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}


#claim count differences
diff1<-log10(co$count.y/co$count.x)
diff2<-abs(co$count.y-co$count.x)
i1<-which(diff2 <=  3)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent good counts = ",pct.good,"\n")

bad<-co[-i,]
write.table(bad,file="febvmarch_badcomp.txt",row.names=F,col.names=T,
quote=F,sep="\t")




#CLAIM COUNT COMPARE
minval<-min(c(co[,2],co[,3]))
lminval<-log10(minval)
maxval<-max(c(co[,2],co[,3]))
lmaxval<-log10(maxval)


library(MASS)
pdf("febvmarch_comp.pdf",onefile=T)
plot(count.y~count.x,data=co,pch=4,cex=.5,log="xy",xlab="feb",ylab="mar",main="count compare",xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$count.x),log10(co$count.y),colramp = Lab.palette,
xlab="feb",ylab="mar",main="count compare",xlim=c(lminval,lmaxval),ylim=c(lminval,lmaxval))
lines(c(lminval,lmaxval),c(lminval,lmaxval),lwd=3,col="red")

dev.off()


 

