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

###removes "Pat" from column names to make denom_fordelivery work in place of rankeddenom - rdh
colnames(co.ranked)[grep("Grp.*Cnt",colnames(co.ranked))]<-gsub("Pat","",colnames(co.ranked)[grep("Grp.*Cnt",colnames(co.ranked))])

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

if(! grp2test){
 co.ranked[is.na(co.ranked)]<-0.1
 co.links[is.na(co.links)]<-0.1
}else{
 co.ranked.grp1<-co.ranked[which(!is.na(co.ranked$Grp1Rank.x) | !is.na(co.ranked$Grp1Rank.y)),]
 co.ranked.grp2<-co.ranked[which(!is.na(co.ranked$Grp2Rank.x) | !is.na(co.ranked$Grp2Rank.y)),]
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


