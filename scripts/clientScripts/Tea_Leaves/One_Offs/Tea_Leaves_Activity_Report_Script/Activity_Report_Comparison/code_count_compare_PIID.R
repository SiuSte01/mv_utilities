#Note: Your old file (activity_report_old.txt)  and new file (activity_report_new.txt) 
#should each be three columns: HMS_PIID, ProcNoDecimal, and Count

#Read in Emdeon OP/Office/ASC activity reports from old and new
old_ar <- read.table("activityreport_old.txt", header=T, sep="\t", as.is=T, na.strings="")
new_ar <- read.table("activityreport_new.txt", header=T, sep="\t", as.is=T, na.strings="")

#Change column names so that count column is not merged
colnames(old_ar) <- c("HMS_PIID","ProcNoDecimal","Count_old")
colnames(new_ar) <- c("HMS_PIID","ProcNoDecimal","Count_new")

#Group by code and sum counts for code
counts_old<-aggregate(Count_old~HMS_PIID+ProcNoDecimal,data=old_ar,sum)
counts_new<-aggregate(Count_new~HMS_PIID+ProcNoDecimal,data=new_ar,sum)

#Merge old and new count together for comparison
merged<-merge(x=counts_old,y=counts_new,all=T)


#Calculate % bad (code taken from scatterQC and column numbers adjusted)
for(i in c(3,4))
{
  idx<-which(is.na(merged[,i]))
  if(length(idx) > 0) {
    merged[idx,i]<-0.1
  }
  
}

#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
               log10(1.00001),log10(1.1),log10(2),Inf)
diff<-log10(merged[,3]/merged[,4])
binned<-cut(diff,breaks=diff.breaks,labels=c(">2xIncr",   
                                             "Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
                                             ">2xDecr"))
cat("change distribution\n")
print(table(binned))
diff2<-abs(merged[,3]-merged[,4])
i1<-which(diff2 <= 10)
i2<-which((diff < log10(1.1)) & (diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent good = ",pct.good,"\n")

bad<-merged[-i,]
write.table(bad,file="bad_records.txt",row.names=F,col.names=T,quote=F,sep="\t")
