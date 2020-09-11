
#specify the old directory here
olddir<-"olddir"
#specify the new directory here
newdir<-getwd()

###########################################################################
scatter.unique<-function(x,y,title=""){
 max.value<-max(max(x),max(y))
 unique.values<-which(!duplicated(paste(x,y)))
 plot( x[unique.values],y[unique.values],xlab="Old File",
 ylab="New File",main=title,pch=4,cex=.5,
 xlim=c(0.1,max.value),ylim=c(0.1,max.value),log="xy")
 lines(c(0.1,max.value),c(0.1,max.value),lwd=3,col="red")
}
###########################################################################


sink("scatterqc_output.txt")
old.indivf<-paste(olddir,"individuals.tab",sep="/")
new.indivf<-paste(newdir,"individuals.tab",sep="/")
old.orgf<-paste(olddir,"organizations.tab",sep="/")
new.orgf<-paste(newdir,"organizations.tab",sep="/")
old.pxdxf<-paste(olddir,"pxdx.tab",sep="/")
new.pxdxf<-paste(newdir,"pxdx.tab",sep="/")

old.indivs<-read.table(old.indivf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.indivs<-read.table(new.indivf,sep="\t",as.is=T,quote="",comment.char="",header=T)
old.orgs<-read.table(old.orgf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.orgs<-read.table(new.orgf,sep="\t",as.is=T,quote="",comment.char="",header=T)
old.pxdx1<-read.table(old.pxdxf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.pxdx1<-read.table(new.pxdxf,sep="\t",as.is=T,quote="",comment.char="",header=T)

i1<-grep("PRACTITIONER_TOTAL",colnames(old.indivs))
old.indiv<-old.indivs[,c(1,i1)]
i1<-grep("PRACTITIONER_TOTAL",colnames(new.indivs))
new.indiv<-new.indivs[,c(1,i1)]

i1<-grep("FAC_TOTAL",colnames(old.orgs))
old.org<-old.orgs[,c(1,i1)]
i1<-grep("FAC_TOTAL",colnames(new.orgs))
new.org<-new.orgs[,c(1,i1)]

i1<-grep("PRACTITIONER_FAC_TOTAL",colnames(old.pxdx1))
wantcols<-c("HMS_PIID","HMS_POID",colnames(old.pxdx1)[i1])
old.pxdx<-old.pxdx1[,wantcols]
i1<-grep("PRACTITIONER_FAC_TOTAL",colnames(new.pxdx1))
wantcols<-c("HMS_PIID","HMS_POID",colnames(new.pxdx1)[i1])
new.pxdx<-new.pxdx1[,wantcols]

cat("Record Count Comparisons\n")
old.indiv.rows<-nrow(old.indiv)
old.org.rows<-nrow(old.org)
old.pxdx.rows<-nrow(old.pxdx)
new.indiv.rows<-nrow(new.indiv)
new.org.rows<-nrow(new.org)
new.pxdx.rows<-nrow(new.pxdx)
indiv.pct.diff<-signif(100*(new.indiv.rows-old.indiv.rows)/old.indiv.rows,2)
org.pct.diff<-signif(100*(new.org.rows-old.org.rows)/old.org.rows,2)
pxdx.pct.diff<-signif(100*(new.pxdx.rows-old.pxdx.rows)/old.pxdx.rows,2)
cat("\tFile\tOld_Count\tNew_Count\tPct_Change\n")
cat("\tIndivs\t",old.indiv.rows,"\t",new.indiv.rows,"\t",paste0(indiv.pct.diff,"%"),"\n")
cat("\tOrgs\t",old.org.rows,"\t\t",new.org.rows,"\t\t",paste0(org.pct.diff,"%"),"\n")
cat("\tPxDx\t",old.pxdx.rows,"\t",new.pxdx.rows,"\t",paste0(pxdx.pct.diff,"%"),"\n\n")

co.indiv<-merge(old.indiv,new.indiv,by="HMS_PIID",all=T)
co.org<-merge(old.org,new.org,by="HMS_POID",all=T)
co.pxdx<-merge(old.pxdx,new.pxdx,by=c("HMS_PIID","HMS_POID"),all=T)

for(i in c(2,3))
{
 idx<-which(is.na(co.indiv[,i]))
 if(length(idx) > 0) {
   co.indiv[idx,i]<-0.1
 }
 idx<-which(is.na(co.org[,i]))
 if(length(idx) > 0) {
   co.org[idx,i]<-0.1
 }
}
for(i in c(3,4))
{
 idx<-which(is.na(co.pxdx[,i]))
 if(length(idx) > 0) {
   co.pxdx[idx,i]<-0.1
 }
}

#counts of differences
diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),
log10(1.00001),log10(1.1),log10(2),Inf)
indiv.diff<-log10(co.indiv[,2]/co.indiv[,3])
indiv.binned<-cut(indiv.diff,breaks=diff.breaks,labels=c(">2xIncr",   
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("Indiv Change Distribution\n")
# print(table(indiv.binned))
indiv.diff2<-abs(co.indiv[,2]-co.indiv[,3])
i1<-which(indiv.diff2 <= 10)
i2<-which((indiv.diff < log10(1.1)) & (indiv.diff > log10(1/1.1)))
i<-union(i1,i2)
pct.good<-100*(length(i)/length(indiv.diff2))
cat("\tTotal percent good = ",pct.good,"\n")
cat("\tCount of records within absolute value of 10 = ",length(i1),"\n")
cat("\tPercent of records within absolute value of 10 = ", length(i1)/nrow(co.indiv)*100,"\n")
cat("\tCount of records within log 10 = ",length(i2),"\n")
cat("\tPercent of records within log 10 = ", length(i2)/nrow(co.indiv)*100,"\n")


# print(length(i))

bad<-co.indiv[-i,]
cat("\tNumber of bad indiv records = ", nrow(bad),"\n\n")

write.table(bad,file="indiv_bad_records.txt",row.names=F,col.names=T,quote=F,sep="\t")

org.diff<-log10(co.org[,2]/co.org[,3])
org.binned<-cut(org.diff,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("Org Change Distribution\n")
# print(table(org.binned))
org.diff2<-abs(co.org[,2]-co.org[,3])
i1<-which(org.diff2 <= 10)
i2<-which((org.diff < log10(1.1)) & (org.diff > log10(1/1.1)))
i<-union(i1,i2)
pct.good<-100*(length(i)/length(org.diff2))
cat("\tTotal percent good = ",pct.good,"\n")
cat("\tCount of records within absolute value of 10 = ",length(i1),"\n")
cat("\tPercent of records within absolute value of 10 = ", length(i1)/nrow(co.org)*100,"\n")
cat("\tCount of records within log 10 = ",length(i2),"\n")
cat("\tPercent of records within log 10 = ", length(i2)/nrow(co.org)*100,"\n")

# print(length(i))

bad<-co.org[-i,]
cat("\tNumber of bad org records = ", nrow(bad),"\n\n")
write.table(bad,file="org_bad_records.txt",row.names=F,col.names=T,quote=F,sep="\t")

pxdx.diff<-log10(co.pxdx[,3]/co.pxdx[,4])
pxdx.binned<-cut(pxdx.diff,breaks=diff.breaks,labels=c(">2xIncr",
"Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",
">2xDecr"))
cat("PxDx Change Distribution\n")
# print(table(pxdx.binned))
pxdx.diff2<-abs(co.pxdx[,3]-co.pxdx[,4])
i1<-which(pxdx.diff2 <= 10)
i2<-which((pxdx.diff < log10(1.1)) & (pxdx.diff > log10(1/1.1)))
i<-union(i1,i2)
pct.good<-100*(length(i)/length(pxdx.diff2))
cat("\tTotal percent good = ",pct.good,"\n")
cat("\tCount of records within absolute value of 10 = ",length(i1),"\n")
cat("\tPercent of records within absolute value of 10 = ", length(i1)/nrow(co.pxdx)*100,"\n")
cat("\tCount of records within log 10 = ",length(i2),"\n")
cat("\tPercent of records within log 10 = ", length(i2)/nrow(co.pxdx)*100,"\n")

# print(length(i))

bad<-co.pxdx[-i,]
cat("\tNumber of bad PxDx records = ", nrow(bad),"\n\n")
write.table(bad,file="pxdx_bad_records.txt",row.names=F,col.names=T,quote=F,sep="\t")

sink()

pdf("comparisons.pdf",onefile=T)
scatter.unique(co.indiv[,2],co.indiv[,3],"Indivs Volume Plot")
indiv.max<-max(max(co.indiv[,2]),max(co.indiv[,3]))
indiv.min<-min(min(co.indiv[,2]),min(co.indiv[,3]))
l.indivmax<-log10(indiv.max)
l.indivmin<-log10(indiv.min)
#plot(co.indiv[,2],co.indiv[,3],xlab="Old",
#ylab="New",main="Indivs Volume Plot",pch=4,cex=.5,
#xlim=c(.1,indiv.max),ylim=c(0.1,indiv.max),log="xy")
#lines(c(0.1,indiv.max),c(0.1,indiv.max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co.indiv[,2]),log10(co.indiv[,3]),colramp = Lab.palette,
xlab="Old",ylab="New",main="Indivs Volume Heat Map",xlim=c(l.indivmin,l.indivmax),ylim=c(l.indivmin,l.indivmax))
lines(c(l.indivmin,l.indivmax),c(l.indivmin,l.indivmax),lwd=3,col="red")

scatter.unique(co.org[,2],co.org[,3],"Orgs Volume Plot")
org.max<-max(max(co.org[,2]),max(co.org[,3]))
org.min<-min(min(co.org[,2]),min(co.indiv[,3]))
l.orgmax<-log10(org.max)
l.orgmin<-log10(org.min)
#plot(co.org[,2],co.org[,3],xlab="Old",
#ylab="New",main="Orgs Volume Plot",pch=4,cex=.5,
#xlim=c(.1,org.max),ylim=c(0.1,org.max),log="xy")
#lines(c(0.1,org.max),c(0.1,org.max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co.org[,2]),log10(co.org[,3]),colramp = Lab.palette,
xlab="Old",ylab="New",main="Orgs Volume Heat Map",xlim=c(l.orgmin,l.orgmax),ylim=c(l.orgmin,l.orgmax))
lines(c(l.orgmin,l.orgmax),c(l.orgmin,l.orgmax),lwd=3,col="red")


scatter.unique(co.pxdx[,3],co.pxdx[,4],"PxDx Volume Plot")
pxdx.max<-max(max(co.pxdx[,3]),max(co.pxdx[,4]))
pxdx.min<-min(min(co.pxdx[,3]),min(co.pxdx[,4]))
l.pxdxmin<-log10(pxdx.min)
l.pxdxmax<-log10(pxdx.max)
#plot(co.pxdx[,3],co.pxdx[,4],xlab="Old",
#ylab="New",main="PxDx Volume Plot",pch=4,cex=.5,
#xlim=c(.1,pxdx.max),ylim=c(0.1,pxdx.max),log="xy")
#lines(c(0.1,pxdx.max),c(0.1,pxdx.max),lwd=3,col="red")
Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
smoothScatter(log10(co.pxdx[,3]),log10(co.pxdx[,4]),colramp = Lab.palette,
xlab="Old",ylab="New",main="PxDx Volume Heat Map",xlim=c(l.pxdxmin,l.pxdxmax),ylim=c(l.pxdxmin,l.pxdxmax))
lines(c(l.pxdxmin,l.pxdxmax),c(l.pxdxmin,l.pxdxmax),lwd=3,col="red")


# dev.off()



# Graph of binned numbers -------------------------------------------------


#Adding labels for the binned %s
bin.labels<-c(">2xIncr","10%to2xIncr","<10%Incr","NoChange","<10%Decr","10%to2xDecr",">2xDecr")

#Graph of bins for each file
#Converted to data frame to have more control over labels and graph
t1 <- table(factor(indiv.binned, levels = levels(indiv.binned)))
t1a<-as.data.frame(t1)
bp1<-barplot(t1a$Freq/sum(t1a$Freq)*100,main="Indivs Binned Changes")
axis(1,at =bp1,labels=bin.labels,cex.axis=.6,las=2)
text(bp1,0,(paste0(round((t1/sum(t1)*100),1),"%")),cex=0.8,pos=3,col="dark blue")

t2 <- table(factor(org.binned, levels = levels(org.binned)))
t2a<-as.data.frame(t2)
bp2<-barplot(t2a$Freq/sum(t2a$Freq)*100,main="Orgs Binned Changes")
axis(1,at =bp2,labels=bin.labels,cex.axis=.6,las=2)
text(bp2,0,(paste0(round((t2/sum(t2)*100),1),"%")),cex=0.8,pos=3,col="dark blue")

t3 <- table(factor(pxdx.binned, levels = levels(pxdx.binned)))
t3a<-as.data.frame(t3)
bp3<-barplot(t3a$Freq/sum(t3a$Freq)*100,main="PxDx Binned Changes")
axis(1,at =bp3,labels=bin.labels,cex.axis=.6,las=2)
text(bp3,0,(paste0(round((t3/sum(t3)*100),1),"%")),cex=0.8,pos=3,col="dark blue")

dev.off()


# 11 x 11 Comparison: Indivs ---------------------------------------------------------
sink("scatterqc_output.txt",append = T)

#If HealthGrades deliverable, the rank is in a different column than for other projects.
#So, for HG, don't run this crosstab.

dir<-getwd()
hg_dir<-grepl("HealthGrades",dir)

if(hg_dir==1){
  #If in HG directory, expect HG folder structure
  cat("\n\nNOTE: Indivs rank comparison does not run for HealthGrades projects")
}else{
  #Indivs Old: Grab just PIID and rank column. Change rank name to label as old.
  old.indiv.rank<-old.indivs[,c(1,19)]
  colnames(old.indiv.rank)[2] <- "OLD_Rank"
  
  #Indivs New: Grab just PIID and rank column. Change rank name to label as new.
  new.indiv.rank<-new.indivs[,c(1,19)]
  colnames(new.indiv.rank)[2] <- "NEW_Prac_Natl_Rank"
  
  #Indivs Compare: Merge ranks and run old rank vs. new rank crosstab
  merged.indiv.rank<-merge(old.indiv.rank,new.indiv.rank,all=T)
  cat("\n\nIndivs: Rank Comparison\n\n")
  table(merged.indiv.rank[, 2:3],exclude=NULL)  
  }

# 11 x 11 Comparison: Orgs ------------------------------------------------

#Orgs Old: Grab just POID and rank column. Change rank name to label as old.
old.org.rank<-old.orgs[,c(1,14)]
colnames(old.org.rank)[2] <- "OLD_Rank"

#Orgs New: Grab just POID and rank column. Change rank name to label as new.
new.org.rank<-new.orgs[,c(1,14)]
colnames(new.org.rank)[2] <- "NEW_Fac_Natl_Rank"

#Orgs Compare: Merge ranks and run old rank vs. new rank crosstab
merged.org.rank<-merge(old.org.rank,new.org.rank,all=T)
cat("\n\nOrgs: Rank Comparison\n\n")
table(merged.org.rank[, 2:3],exclude=NULL)


# # 11 x 11 Comparison: PxDx ------------------------------------------------
# 
# #PxDx Old: Grab just PIID, POID, and rank column. Change rank name to label as old.
# old.pxdx.rank<-old.pxdx1[,c(1,10,24)]
# colnames(old.pxdx.rank)[3] <- "OLD_Rank"
# 
# #PxDx New: Grab just PIID, POID, and rank column. Change rank name to label as new.
# new.pxdx.rank<-new.pxdx1[,c(1,10,24)]
# colnames(new.pxdx.rank)[3] <- "NEW_Prac_Fac_Natl_Rank"
# 
# #PxDx Compare: Merge ranks and run old rank vs. new rank crosstab
# merged.pxdx.rank<-merge(old.pxdx.rank,new.pxdx.rank,all=T)
# cat("\n\nPxDx: Rank Comparison\n\n")
# table(merged.pxdx.rank[, 3:4],exclude=NULL)



# Added July 2018: Total Org Volume ---------------------------------------

cat("\n\nOrgs: Comparison of Total Org Volumes")
#Check that same count is being used across new and old files
count_col_old<-grep("FAC_TOTAL",colnames(old.orgs),value = T)
count_col_new<-grep("FAC_TOTAL",colnames(new.orgs),value = T)

count_col_old_value<-tail(unlist(strsplit(count_col_old,"_")),n=1)
count_col_new_value<-tail(unlist(strsplit(count_col_new,"_")),n=1)

if(count_col_new_value==count_col_old_value){
  cat("\n\nCount type:",count_col_new_value)
} else {
  cat("\n\n***WARNING: Type of count is different in new and old org files!***")
  cat("\n\tOld count column:",count_col_old_value)
  cat("\n\tNew count column:",count_col_new_value)
}

#Calculate sum for each org file
old_org_total<-sum(old.orgs[,count_col_old])
new_org_total<-sum(new.orgs[,count_col_new])

cat("\nSum of counts for old orgs file:",old_org_total)
cat("\nSum of counts for new orgs file:",new_org_total)
pct_change_org_total<-(new_org_total-old_org_total)/old_org_total*100
cat("\nOrg Total Volume Percent Change:",pct_change_org_total,"%")

sink()