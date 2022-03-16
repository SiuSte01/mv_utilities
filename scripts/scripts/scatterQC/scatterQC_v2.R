#specify the old (standard process) directory here
#olddir<-"/vol/cs/clientprojects/Tea_Leaves/2016_06_30_PxDx_and_INA/2016_06_30_INA_Emdeon/Onco_INA/Onco_dxpx_INA/Comb"
#specify the new (aggregation process) directory here
#newdir<-"/vol/cs/clientprojects/Tea_Leaves/2016_07_29_PxDx_and_INA/2016_07_29_INA_Emdeon/Onco_INA/Onco_dxpx_INA/Comb"

#olddir<-"/vol/cs/CS_PayerProvider/Ryan/R/INAQC_test/old_test"
#newdir<-"/vol/cs/CS_PayerProvider/Ryan/R/INAQC_test/new_test"

args = commandArgs(trailingOnly=TRUE)

if(length(args)==0){
 #olddir<-"/vol/cs/clientprojects/Ellis/2016_12_23_Ellis_INA/GenSurg_INA/GenSurg_pxcohort_INA/Comb"
 #newdir<-"/vol/cs/clientprojects/Ellis/2017_01_24_Ellis_test/GenSurg_INA/GenSurg_pxcohort_INA/Comb"
 #outdir<-"/vol/cs/clientprojects/Ellis/2017_01_24_Ellis_test/QA_Results"
 stop("This script requires 3 arguments: olddir newdir outdir")
}else if(length(args)==3){
 olddir<-args[1]
 newdir<-args[2]
 outdir<-args[3]
}else{
 stop("incorrect # of args")
}

dir.create(outdir)

################################################
#check for INA and PXDX files###################
################################################
files<-Sys.glob(paste(olddir,"/*",sep=""))
is.ina<-paste(olddir,"/links.txt",sep="") %in% files
is.pxdx<-paste(olddir,"/individuals.tab",sep="") %in% files

################################################
#function to plot scatterplot of unique values
scatter.unique<-function(x,y,title=""){
 max.value<-max(max(x,na.rm=T),max(y,na.rm=T))
 unique.values<-which(!duplicated(paste(x,y)))
 plot( x[unique.values],y[unique.values],xlab="Old File",
 ylab="New File",main=title,pch=4,cex=.5,
 xlim=c(0.1,max.value),ylim=c(0.1,max.value),log="xy")
 lines(c(0.1,max.value),c(0.1,max.value),lwd=3,col="red")
}

plot.heatmap<-function(x,y,title=""){
 minval<-log10(min(c(x,y,na.rm=T)))
 maxval<-log10(max(c(x,y,na.rm=T)))

 Lab.palette <- colorRampPalette(c("blue", "orange", "red"), space = "Lab")
 smoothScatter(log10(x),log10(y),colramp = Lab.palette,
 xlab="Old File",ylab="New File",main=title,xlim=c(minval,maxval),ylim=c(minval,maxval))
 lines(c(minval,maxval),c(minval,maxval),lwd=3,col="red")
}

plot.binbars<-function(binned.data,name){
 t1a <- as.data.frame(table(binned.data))
 bp1<-barplot(t1a$Freq/sum(t1a$Freq)*100,main=name)
 axis(1,at =bp1,labels=t1a[,1],cex.axis=.6,las=2)
 text(bp1,0,(paste0(round((t1a$Freq/sum(t1a$Freq)*100),1),"%")),cex=0.8,pos=3,col="dark blue")
}

test.range<-function(percent,number,df.test,input1,input2,text){
 if (! any(grepl(input1,colnames(df.test))) | ! any(grepl(input2,colnames(df.test)))  ){stop("fields not found")}
 df.test<-df.test[which(df.test[[input1]] != 0.1 & ! is.na(df.test[[input1]]) & df.test[[input2]] != 0.1 & ! is.na(df.test[[input2]])),]
 i<-nrow(df.test[which((df.test[[input1]]/df.test[[input2]] < percent & df.test[[input1]]/df.test[[input2]] > 1/percent) | abs(df.test[[input1]]-df.test[[input2]]) <= number),]) #values that changed by <= 5 or +/- 10%
 percent.matching<-100*(i/nrow(df.test))
 return(paste(text,percent.matching))
}

calculate.percent.of<-function(df.test,input1,input2){
 df.test<-df.test[which(df.test[[input1]] != 0.1 & df.test[[input2]] != 0.1 & !is.na(df.test[[input1]]) & !is.na(df.test[[input2]])),]
 return(log10(df.test[[input1]]/df.test[[input2]]))
}


################################################

###?in rankeddenom, piids in group2 but not group1 have NA values for group1 volume. In denom_fordelivery, they have 0. This may cause complications in how we calculate records added and lost. This is not true of ranks, only counts.

if(is.ina){
old.linksf<-paste(olddir,"links.txt",sep="/")
new.linksf<-paste(newdir,"links.txt",sep="/")
old.denomf<-paste(olddir,"denom_fordelivery.txt",sep="/")
new.denomf<-paste(newdir,"denom_fordelivery.txt",sep="/")
#old.rankedf<-paste(olddir,"rankeddenom.txt",sep="/")
#new.rankedf<-paste(newdir,"rankeddenom.txt",sep="/")

old.links<-read.table(old.linksf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.links<-read.table(new.linksf,sep="\t",as.is=T,quote="",comment.char="",header=T)
old.denom<-read.table(old.denomf,sep="\t",as.is=T,quote="",comment.char="",header=T)
new.denom<-read.table(new.denomf,sep="\t",as.is=T,quote="",comment.char="",header=T)
#old.ranked<-read.table(old.rankedf,sep="\t",as.is=T,quote="",comment.char="",header=T)
#new.ranked<-read.table(new.rankedf,sep="\t",as.is=T,quote="",comment.char="",header=T)

grp2test<-any(grepl("Grp2Rank",colnames(old.denom))) #if Grp2Rank is present, we will treat this as a 2 group INA. rdh

#counting nodes and edges
old.link.rows<-nrow(old.links)
old.denom.rows<-nrow(old.denom)
new.link.rows<-nrow(new.links)
new.denom.rows<-nrow(new.denom)

link.pct.diff<-signif(100*(new.link.rows-old.link.rows)/old.link.rows,2)
denom.pct.diff<-signif(100*(new.denom.rows-old.denom.rows)/old.denom.rows,2)


co.denom<-merge(old.denom,new.denom,by="HMS_ID",all=T)
co.links<-merge(old.links,new.links,by="VAR1",all=T)
#co.ranked<-merge(old.ranked,new.ranked,by="HMS_ID",all=T)
co.ranked<-co.denom

##Net loss and gain
# num links and denom only in old/new
### denom
denom.loss <- co.denom[which(is.na(co.denom$Grp1Rank.y) & ! is.na(co.denom$Grp1Rank.x)),]
denom.gain <- co.denom[which(is.na(co.denom$Grp1Rank.x) & ! is.na(co.denom$Grp1Rank.y)),]

old.denom.grp1.rows<-nrow(old.denom[which(! is.na(old.denom$Grp1Rank)),])
denom.l.count <- paste("count of dropped IDs = ",nrow(denom.loss))
denom.g.count <- paste("count of net new IDs = ",nrow(denom.gain))

denom.l.pct1 <- (nrow(denom.loss)/old.denom.grp1.rows)*100
denom.g.pct1 <- (nrow(denom.gain)/old.denom.grp1.rows)*100
denom.l.pct <- paste("percent of dropped IDs = ",denom.l.pct1)
denom.g.pct <- paste("percent of net new IDs = ",denom.g.pct1)

if (grp2test){
 denom.l.count <- paste("Grp1 count of dropped IDs = ",nrow(denom.loss))
 denom.g.count <- paste("Grp1 count of net new IDs = ",nrow(denom.gain))
 denom.l.pct <- paste("Grp1 percent of dropped IDs = ",denom.l.pct1)
 denom.g.pct <- paste("Grp1 percent of net new IDs = ",denom.g.pct1)


 denom.loss2 <- co.denom[which(is.na(co.denom$Grp2Rank.y) & ! is.na(co.denom$Grp2Rank.x)),]
 denom.gain2 <- co.denom[which(is.na(co.denom$Grp2Rank.x) & ! is.na(co.denom$Grp2Rank.y)),]
 denom.l.count2 <- paste("Grp2 count of dropped IDs = ",nrow(denom.loss2))
 denom.g.count2 <- paste("Grp2 count of net new IDs = ",nrow(denom.gain2))

 old.denom.grp2.rows<-nrow(old.denom[which(! is.na(old.denom$Grp2Rank)),])
 denom.l.pct12 <- (nrow(denom.loss2)/old.denom.grp2.rows)*100
 denom.g.pct12 <- (nrow(denom.gain2)/old.denom.grp2.rows)*100
 denom.l.pct2 <- paste("Grp2 percent of dropped IDs = ",denom.l.pct12)
 denom.g.pct2 <- paste("Grp2 percent of net new IDs = ",denom.g.pct12)

}

###updated the above to count only those in the new of one group but not in the old of the same group, rather than relying on rows, as those could be influenced by group2 as well. rdh.

###links are between grp1 and 2 if there are 2, 1 and 1 if only one, so this does not need changed. rdh

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

if(!grp2test){
 denom.table<-(table(co.denom[,2],co.denom[,4],exclude=NULL))
}else{
 denom.table1<-(table(co.denom[["Grp1Rank.x"]],co.denom[["Grp1Rank.y"]],exclude=NULL))
 denom.table2<-(table(co.denom[["Grp2Rank.x"]],co.denom[["Grp2Rank.y"]],exclude=NULL))
}

rank.table<-(table(co.links[,3],co.links[,5],exclude=NULL))

###removes "Pat" from column names to make denom_fordelivery work in place of rankeddenom - rdh
colnames(co.ranked)[grep("Grp.*Cnt",colnames(co.ranked))]<-gsub("Pat","",colnames(co.ranked)[grep("Grp.*Cnt",colnames(co.ranked))])

###in rankeddenom, piids in group2 but not group1 have NA values for group1 volume. In denom_fordelivery, they have 0. This may cause complications in how we calculate records added and lost. This is not true of ranks, only counts. In order to stop this breaking log plots, counts are set to NA.
co.ranked[,grep("Grp.*Cnt",colnames(co.ranked))][co.ranked[,grep("Grp.*Cnt",colnames(co.ranked))]==0]<-NA

if(! grp2test){
 co.ranked[is.na(co.ranked)]<-0.1
 co.links[is.na(co.links)]<-0.1
}else{
 co.ranked.grp1<-co.ranked[which(!is.na(co.ranked$Grp1Rank.x) | !is.na(co.ranked$Grp1Rank.y)),]
 co.ranked.grp2<-co.ranked[which(!is.na(co.ranked$Grp2Rank.x) | !is.na(co.ranked$Grp2Rank.y)),]
 #co.ranked.grp1<-co.ranked[which(!is.na(co.ranked$Grp1.x) | !is.na(co.ranked$Grp1.y)),]
 #co.ranked.grp2<-co.ranked[which(!is.na(co.ranked$Grp2.x) | !is.na(co.ranked$Grp2.y)),]
 co.ranked.grp1[is.na(co.ranked.grp1)]<-0.1
 co.ranked.grp2[is.na(co.ranked.grp2)]<-0.1
 co.links[is.na(co.links)]<-0.1
}

###########################################################
###########################################################

###
####calculate % good - for Denom should be change of less than 10 or within 10% of old value

diff.breaks<-c(-Inf,log10(0.5),log10(1/1.1),log10(1/1.00001),log10(1.00001),log10(1.1),log10(2),Inf)
dbin.label <- paste(">2xIncr","Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",">2xDecr",sep="\t")

if (! grp2test){
 dx.ranked.count.diff<-calculate.percent.of(co.ranked,"Grp1Cnt.x","Grp1Cnt.y")
 dx.ranked.binned<-cut(dx.ranked.count.diff,breaks=diff.breaks,labels=c(unlist(strsplit(dbin.label,split="\t"))))
 dx.bin.ranked<-table(dx.ranked.binned)

 print.dx.10<-test.range(1.1,5,co.ranked,"Grp1Cnt.x","Grp1Cnt.y","Grp1 denom good 10% =")
 print.dx.25<-test.range(1.25,10,co.ranked,"Grp1Cnt.x","Grp1Cnt.y","Grp1 denom good 25% =")
}else{
 ###group1  
 dx.ranked.count.diffg1<-calculate.percent.of(co.ranked.grp1,"Grp1Cnt.x","Grp1Cnt.y")
 dx.ranked.binnedg1<-cut(dx.ranked.count.diffg1,breaks=diff.breaks,labels=c(unlist(strsplit(dbin.label,split="\t"))))
 dx.bin.rankedg1<-table(dx.ranked.binnedg1)

 print.dx.10g1<-test.range(1.1,5,co.ranked.grp1,"Grp1Cnt.x","Grp1Cnt.y","Grp1 denom good 10% =")
 print.dx.25g1<-test.range(1.25,10,co.ranked.grp1,"Grp1Cnt.x","Grp1Cnt.y","Grp1 denom good 25% =")

 ###group2
 dx.ranked.count.diffg2<-calculate.percent.of(co.ranked.grp2,"Grp2Cnt.x","Grp2Cnt.y")
 dx.ranked.binnedg2<-cut(dx.ranked.count.diffg2,breaks=diff.breaks,labels=c(unlist(strsplit(dbin.label,split="\t"))))
 dx.bin.rankedg2<-table(dx.ranked.binnedg2)

 print.dx.10g2<-test.range(1.1,5,co.ranked.grp2,"Grp2Cnt.x","Grp2Cnt.y","Grp2 denom good 10% =")
 print.dx.25g2<-test.range(1.25,10,co.ranked.grp2,"Grp2Cnt.x","Grp2Cnt.y","Grp2 denom good 25% =")
}

######################################################################
######################################################################

#calculate % good - for links should be change of less than 2 or within 10% of old value

#links.diff<-log10(co.links$COUNT.x/co.links$COUNT.y)
#links.diff2<-abs(co.links$COUNT.x-co.links$COUNT.y)
#i1<-which(links.diff2 <= 2)
#i2<-which((links.diff < log10(1.1)) & (links.diff > log10(1/1.1)))
#i<-union(i1,i2)
#links.good<-100*(length(i)/length(links.diff2))
#links.good.pct<-paste("percent links good = ",links.good)

links.good.pct<-test.range(1.1,5,co.links,"COUNT.x","COUNT.y","Percent links good =")
links.diff<-calculate.percent.of(co.links,"COUNT.x","COUNT.y")

links.binned<-cut(links.diff,breaks=diff.breaks,labels=c(">2xIncr","Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",">2xDecr"))
bin.links <- table(links.binned)
lbin.label <- paste(">2xIncr","Betwn10%and2xIncr","<10%Incr","NoChange","<10%Decr","Betwn10%and2xDecr",">2xDecr")



#### ------------------------ OUTPUT CHURN ----------
## combine results into one DF for export

sink(paste(outdir,"scatterqc_output.txt",sep="/"))
cat("Old directory: ",olddir,"\n")
cat("New directory: ",newdir,"\n\n")
if(! grp2test){
 cat("Record Count Comparisons","\n")
 cat("\tFile\tOld_Count\tNew_Count\tPct_Change\n")
 cat("\tlinks\t",old.link.rows,"\t",new.link.rows,"\t",link.pct.diff,"\n")
 cat("\tdenom\t",old.denom.rows,"\t",new.denom.rows,"\t",denom.pct.diff,"\n")
 cat("\n\n","----------------------------------------------------------","\n\n")
 cat("Churn results Grp1","\n")
 cat("\t",print.dx.10,"\n")
 cat("\t",print.dx.25,"\n")
 cat("\t",denom.l.count,"\n\t",denom.l.pct,"\n\t",denom.g.count,"\n\t",denom.g.pct,"\n")
 cat("denom change distr","\n")
 print(data.frame("Level"=unlist(dimnames(dx.bin.ranked)),"Count"=as.integer(dx.bin.ranked),row.names=NULL),right=F,row.names=F)
 cat("\n11 by 11 table for denom ranks\n")
 print(denom.table)
 cat("\n\n","----------------------------------------------------------","\n\n")
 cat("Churn results Links\n")
 cat("\t",links.good.pct,"\n\t",links.l.count,"\n\t",links.l.pct,"\n\t",links.g.count,"\n\t",links.g.pct,"\n",sep="")
 cat("Link change distr\n")
 print(data.frame("Level"=unlist(dimnames(bin.links)),"Count"=as.integer(bin.links),row.names=NULL),right=F,row.names=F)
 cat("\n11 by 11 table for SOR values\n")
 print(rank.table)

}else{
 {
  cat("Record Count Comparisons","\n")
  cat("\tFile\tOld_Count\tNew_Count\tPct_Change\n")
  cat("\tlinks\t",old.link.rows,"\t",new.link.rows,"\t",link.pct.diff,"\n")
  cat("\tdenom\t",old.denom.rows,"\t",new.denom.rows,"\t",denom.pct.diff,"\n")
  cat("\n\n","----------------------------------------------------------","\n\n")
  cat("Churn results Grp1","\n")
  cat("\t",print.dx.10g1,"\n")
  cat("\t",print.dx.25g1,"\n")
  cat("\t",denom.l.count,"\n\t",denom.l.pct,"\n\t",denom.g.count,"\n\t",denom.g.pct,"\n")
  cat("denom change distr","\n")
  print(data.frame("Level"=unlist(dimnames(dx.bin.rankedg1)),"Count"=as.integer(dx.bin.rankedg1),row.names=NULL),right=F,row.names=F)
  cat("\n11 by 11 table for Grp1 denom ranks\n")
  print(denom.table1)
  cat("\n\n","----------------------------------------------------------","\n\n")
  cat("Churn results Grp2","\n")
  cat("\t",print.dx.10g2,"\n")
  cat("\t",print.dx.25g2,"\n")
  cat("\t",denom.l.count2,"\n\t",denom.l.pct2,"\n\t",denom.g.count2,"\n\t",denom.g.pct2,"\n")
  cat("denom change distr","\n")
  print(data.frame("Level"=unlist(dimnames(dx.bin.rankedg2)),"Count"=as.integer(dx.bin.rankedg2),row.names=NULL),right=F,row.names=F)
  cat("\n11 by 11 table for Grp2 denom ranks\n")
  print(denom.table2)
  cat("\n\n","----------------------------------------------------------","\n\n")
  cat("Churn results Links\n")
  cat("\t",links.good.pct,"\n\t",links.l.count,"\n\t",links.l.pct,"\n\t",links.g.count,"\n\t",links.g.pct,"\n",sep="")
  cat("Link change distr\n")
  print(data.frame("Level"=unlist(dimnames(bin.links)),"Count"=as.integer(bin.links),row.names=NULL),right=F,row.names=F)
  cat("\n11 by 11 table for SOR values\n")
  print(rank.table)
 }
}
sink()

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


pdf(paste(outdir,"comparisons.pdf",sep="/"),onefile=T)


#plots of link counts - rdh
scatter.unique(co.links$COUNT.x,co.links$COUNT.y,"Links")
plot.heatmap(co.links$COUNT.x,co.links$COUNT.y,"Links")
plot.binbars(links.binned,"Links Binned Changes")

if(! grp2test){ 
 scatter.unique(co.ranked$Grp1Cnt.x,co.ranked$Grp1Cnt.y,"Group 1 denom")
 plot.heatmap(co.ranked$Grp1Cnt.x,co.ranked$Grp1Cnt.y,"Group 1 denom")
 plot.binbars(dx.ranked.binned,"Group 1 Binned Changes")
}else{
 #group1 plots
 scatter.unique(co.ranked.grp1$Grp1Cnt.x,co.ranked.grp1$Grp1Cnt.y,"Group 1 denom")
 plot.heatmap(co.ranked.grp1$Grp1Cnt.x,co.ranked.grp1$Grp1Cnt.y,"Group 1 denom")
 plot.binbars(dx.ranked.binnedg1,"Group 1 Binned Changes")
 #group2 plots
 scatter.unique(co.ranked.grp2$Grp1Cnt.x,co.ranked.grp2$Grp1Cnt.y,"Group 2 denom")
 plot.heatmap(co.ranked.grp2$Grp1Cnt.x,co.ranked.grp2$Grp1Cnt.y,"Group 2 denom")
 plot.binbars(dx.ranked.binnedg2,"Group 2 Binned Changes")
}

dev.off()

}

if(is.pxdx){

#specify the old directory here
#olddir<-"olddir"
#specify the new directory here
#newdir<-getwd()

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


sink()

}
