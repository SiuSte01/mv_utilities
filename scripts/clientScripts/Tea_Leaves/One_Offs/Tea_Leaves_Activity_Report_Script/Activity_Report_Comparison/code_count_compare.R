#Note: Your old file (activity_report_jan.txt)  and new file (activity_report_feb.txt) 
# should each be two columns: ProcNoDecimal and Count

#Read in Emdeon OP/Office/ASC activity reports from Jan and Feb
jan_ar <- read.table("activityreport_jan.txt", header=T, sep="\t", as.is=T, na.strings="")
feb_ar <- read.table("activityreport_feb.txt", header=T, sep="\t", as.is=T, na.strings="")

#Change column names so that count column is not merged
colnames(jan_ar) <- c("ProcNoDecimal","Count_Jan")
colnames(feb_ar) <- c("ProcNoDecimal","Count_Feb")

#Group by code and sum counts for code
counts_jan<-aggregate(Count_Jan~ProcNoDecimal,data=jan_ar,sum)
counts_feb<-aggregate(Count_Feb~ProcNoDecimal,data=feb_ar,sum)

#Merge Jan and Feb count together for comparison
merged<-merge(x=counts_jan,y=counts_feb,all=T)


#Calculate % bad (code taken from scatterQC and column numbers adjusted)
for(i in c(2,3))
{
  idx<-which(is.na(merged[,i]))
  if(length(idx) > 0) {
    merged[idx,i]<-0.1
  }
  
}

#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
               log10(1.00001),log10(1.1),log10(2),Inf)
diff<-log10(merged[,2]/merged[,3])
binned<-cut(diff,breaks=diff.breaks,labels=c(">2xIncr",   
                                             "Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
                                             ">2xDecr"))
cat("change distribution\n")
print(table(binned))
diff2<-abs(merged[,2]-merged[,3])
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
