og<-read.hms("organizations_grams.tab",na.strings=c(""," "),scanlen=8500)

totalcols<-list()
totalsums<-list()
for (i in grep("TOTAL",colnames(og))){print(i);totalcols<-c(totalcols,colnames(og[i]));print(class(og[,i]));totalsums<-c(totalsums,sum(og[,i],na.rm=T))}

counts<-data.frame("NAME"=unlist(totalcols),"COUNT"=unlist(totalsums))

write.hms(counts,"national_totals.tab")

