### changes needed in 4 locations - specify old and new directories here, and old and new prefixes on lines 9 and 10
########for june 2015, update table 4 comparisons to account for addition of state value
##specify the old (standard process) directory here
olddir<-"/vol/cs/clientprojects/Genentech/Lucentis_POC/2015_04_24_Delivery/"
##specify the new (aggregation process) directory here
newdir<-"/vol/cs/clientprojects/Genentech/Lucentis_POC/2015_05_28_Delivery/"

##update the new and old prefixes
old_pre<-paste("Genentech_Apr2015")
new_pre<-paste("Genentech_May2015")



###
### table loading ----------------------------------
###

#assigning table names to load

old.tab1n<-paste(olddir,old_pre,"_table1_PtntPayer.txt",sep="")
new.tab1n<-paste(newdir,new_pre,"_table1_PtntPayer.txt",sep="")

old.tab2n<-paste(olddir,old_pre,"_table2_PtntFac.txt",sep="")
new.tab2n<-paste(newdir,new_pre,"_table2_PtntFac.txt",sep="")

old.tab3n<-paste(olddir,old_pre,"_table3_DrugPayer.txt",sep="")
new.tab3n<-paste(newdir,new_pre,"_table3_DrugPayer.txt",sep="")

old.tab4n<-paste(olddir,old_pre,"_table4_RevenueUnit.txt",sep="")
new.tab4n<-paste(newdir,new_pre,"_table4_RevenueUnit.txt",sep="")

old.tab5n<-paste(olddir,old_pre,"_table5_DrugPayer_noMed.txt",sep="")
new.tab5n<-paste(newdir,new_pre,"_table5_DrugPayer_noMed.txt",sep="")

### load tables

old.tab1 <- read.table(old.tab1n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)
new.tab1 <- read.table(new.tab1n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)

old.tab2 <- read.table(old.tab2n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)
new.tab2 <- read.table(new.tab2n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)

old.tab3 <- read.table(old.tab3n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)
new.tab3 <- read.table(new.tab3n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)

old.tab4 <- read.table(old.tab4n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)
new.tab4 <- read.table(new.tab4n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)

old.tab5 <- read.table(old.tab5n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)
new.tab5 <- read.table(new.tab5n,sep="\t",as.is=T,quote="",comment.char="",header=T,fill=TRUE)

###
###table1 comparisons -------------------------------------
###

cat("number of rows in old table1 = ",nrow(old.tab1),"\n")
cat("number of rows in new table1= ",nrow(new.tab1),"\n")

co<-merge(old.tab1,new.tab1,by=c("MONTH","BUCKET","PAYER_NAME","STATE","MSA"),all=T)
for(i in c(6:7))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}
minval<-min(c(co[,6],co[,7]))
lminval<-log10(minval)
maxval<-max(c(co[,6],co[,7]))
lmaxval<-log10(maxval)

library(MASS)
pdf("comp_tab1.pdf",onefile=T)
plot(PATIENT_COUNT.y~PATIENT_COUNT.x,data=co,pch=4,cex=.5,log="xy",xlab="Old",ylab="New",
xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$PATIENT_COUNT.x),log10(co$PATIENT_COUNT.y),colramp = Lab.palette,
xlab="Old",ylab="New",xlim=c(lminval,lmaxval),ylim=c(lminval,lmaxval))
lines(c(lminval,lmaxval),c(lminval,lmaxval),lwd=3,col="red")
dev.off()

diff1<-log10(co$PATIENT_COUNT.y/co$PATIENT_COUNT.x)
diff2<-abs(co$PATIENT_COUNT.y-co$PATIENT_COUNT.x)
i1<-which(diff2 <=  10)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
bad<-co[-i,]
write.table(bad,file="bad_tab1comp.txt",row.names=F,col.names=T,
quote=F,sep="\t")

idx<-which(diff1 > log10(50))
vbig<-co[idx,]
write.table(vbig,file="wayoff_tab1.txt",row.names=F,col.names=T,quote=F,
sep="\t")

###
###table2 comparisons ----------------------------------------------
###

old.tab2<-old.tab2[,c(1,2,3,13)]
new.tab2<-new.tab2[,c(1,2,3,13)]

cat("number of rows in old table2 = ",nrow(old.tab2),"\n")
cat("number of rows in new table2= ",nrow(new.tab2),"\n")

co<-merge(old.tab2,new.tab2,by=c("MONTH","BUCKET","HMS_POID"),all=T)
for(i in c(4:5))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}
minval<-min(c(co[,4],co[,5]))
lminval<-log10(minval)
maxval<-max(c(co[,4],co[,5]))
lmaxval<-log10(maxval)

library(MASS)
pdf("comp_tab2.pdf",onefile=T)
plot(PATIENT_COUNT.y~PATIENT_COUNT.x,data=co,pch=4,cex=.5,log="xy",xlab="Old",ylab="New",
xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$PATIENT_COUNT.x),log10(co$PATIENT_COUNT.y),colramp = Lab.palette,
xlab="Old",ylab="New",xlim=c(lminval,lmaxval),ylim=c(lminval,lmaxval))
lines(c(lminval,lmaxval),c(lminval,lmaxval),lwd=3,col="red")
dev.off()

diff1<-log10(co$PATIENT_COUNT.y/co$PATIENT_COUNT.x)
diff2<-abs(co$PATIENT_COUNT.y-co$PATIENT_COUNT.x)
i1<-which(diff2 <=  10)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
bad<-co[-i,]
write.table(bad,file="bad_tab2comp.txt",row.names=F,col.names=T,
quote=F,sep="\t")

idx<-which(diff1 > log10(50))
vbig<-co[idx,]
write.table(vbig,file="wayoff_tab2.txt",row.names=F,col.names=T,quote=F,
sep="\t")

###
###table3 comparisons --------------------------------
###


cat("number of rows in old table3 = ",nrow(old.tab3),"\n")
cat("number of rows in new table3= ",nrow(new.tab3),"\n")

co<-merge(old.tab3,new.tab3,by=c("MONTH","BUCKET","PAYER_NAME","GEO"),all=T)
for(i in c(5:6))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}
minval<-min(c(co[,5],co[,6]))
lminval<-log10(minval)
maxval<-max(c(co[,5],co[,6]))
lmaxval<-log10(maxval)

library(MASS)
pdf("comp_tab3.pdf",onefile=T)
plot(PRODUCT_COUNT.y~PRODUCT_COUNT.x,data=co,pch=4,cex=.5,log="xy",xlab="Old",ylab="New",
xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$PRODUCT_COUNT.x),log10(co$PRODUCT_COUNT.y),colramp = Lab.palette,
xlab="Old",ylab="New",xlim=c(lminval,lmaxval),ylim=c(lminval,lmaxval))
lines(c(lminval,lmaxval),c(lminval,lmaxval),lwd=3,col="red")
dev.off()

diff1<-log10(co$PRODUCT_COUNT.y/co$PRODUCT_COUNT.x)
diff2<-abs(co$PRODUCT_COUNT.y-co$PRODUCT_COUNT.x)
i1<-which(diff2 <=  10)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
bad<-co[-i,]
write.table(bad,file="bad_tab3comp.txt",row.names=F,col.names=T,
quote=F,sep="\t")

idx<-which(diff1 > log10(50))
vbig<-co[idx,]
write.table(vbig,file="wayoff_tab3.txt",row.names=F,col.names=T,quote=F,
sep="\t")


###
###table 4 comparisons --------------------------------
###

#drop state from may tables as no state field to compare
#### for june run, add in state and  merge on state as well for ongoing comparisons
####
new.tab4<-new.tab4[,c(1,2,3,5)]

cat("number of rows in old table4 = ",nrow(old.tab4),"\n")
cat("number of rows in new table4= ",nrow(new.tab4),"\n")

co<-merge(old.tab4,new.tab4,by=c("BUCKET","MONTH","PAY_NAME"),all=T)
for(i in c(4:5))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}
minval<-min(c(co[,4],co[,5]))
lminval<-log10(minval)
maxval<-max(c(co[,4],co[,5]))
lmaxval<-log10(maxval)

library(MASS)
pdf("comp_tab4.pdf",onefile=T)
plot(REVENUE_UNITS.y~REVENUE_UNITS.x,data=co,pch=4,cex=.5,log="xy",xlab="Old",ylab="New",
xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$REVENUE_UNITS.x),log10(co$REVENUE_UNITS.y),colramp = Lab.palette,
xlab="Old",ylab="New",xlim=c(minval,lmaxval),ylim=c(minval,lmaxval))
lines(c(minval,lmaxval),c(minval,lmaxval),lwd=3,col="red")
dev.off()

diff1<-log10(co$REVENUE_UNITS.y/co$REVENUE_UNITS.x)
diff2<-abs(co$REVENUE_UNITS.y-co$REVENUE_UNITS.x)
i1<-which(diff2 <=  10)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
bad<-co[-i,]
write.table(bad,file="bad_tab4comp.txt",row.names=F,col.names=T,
quote=F,sep="\t")

idx<-which(diff1 > log10(50))
vbig<-co[idx,]
write.table(vbig,file="wayoff_tab4.txt",row.names=F,col.names=T,quote=F,
sep="\t")


###
###table 5 comparisons --------------------------------
###


cat("number of rows in old table5 = ",nrow(old.tab5),"\n")
cat("number of rows in new table5= ",nrow(new.tab5),"\n")

co<-merge(old.tab5,new.tab5,by=c("MONTH","BUCKET","PAYER_NAME","GEO"),all=T)
for(i in c(5:6))
{
 idx<-which(is.na(co[,i]))
 if(length(idx) > 0) {
   co[idx,i]<-0.1
 }
}
minval<-min(c(co[,5],co[,6]))
lminval<-log10(minval)
maxval<-max(c(co[,5],co[,6]))
lmaxval<-log10(maxval)

library(MASS)
pdf("comp_tab5.pdf",onefile=T)
plot(PRODUCT_COUNT.y~PRODUCT_COUNT.x,data=co,pch=4,cex=.5,log="xy",xlab="Old",ylab="New",
xlim=c(minval,maxval),ylim=c(minval,maxval))
lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
lines(c(minval,maxval),c(10*minval,10*maxval),lwd=3,col="blue")
lines(c(minval,maxval),c(100*minval,100*maxval),lwd=3,col="green")
lines(c(minval,maxval),c(1000*minval,1000*maxval),lwd=3,col="brown")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co$PRODUCT_COUNT.x),log10(co$PRODUCT_COUNT.y),colramp = Lab.palette,
xlab="Old",ylab="New",xlim=c(lminval,lmaxval),ylim=c(lminval,lmaxval))
lines(c(lminval,lmaxval),c(lminval,lmaxval),lwd=3,col="red")
dev.off()

diff1<-log10(co$PRODUCT_COUNT.y/co$PRODUCT_COUNT.x)
diff2<-abs(co$PRODUCT_COUNT.y-co$PRODUCT_COUNT.x)
i1<-which(diff2 <=  10)
i2<-which((diff1 < log10(1.1)) & (diff1 > log10(1/1.1)))
i<-union(i1,i2)
bad<-co[-i,]
write.table(bad,file="bad_tab5comp.txt",row.names=F,col.names=T,
quote=F,sep="\t")

idx<-which(diff1 > log10(50))
vbig<-co[idx,]
write.table(vbig,file="wayoff_tab5.txt",row.names=F,col.names=T,quote=F,
sep="\t")

