source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

#specify the old (standard process) directory here
olddir<-"/vol/cs/clientprojects/USPI/2016_05_05_ALLSURG_1_PxDx/ALL_SURGERY/Projections"
#specify the new (aggregation process) directory here
newdir<-"/vol/cs/clientprojects/USPI/2016_09_20_ALLSURG_1_PxDx/ALL_SURGERY/Projections"

################################################
#function to plot scatterplot of unique values
scatter.unique<-function(x,y,title=""){
 max.value<-max(max(x),max(y))
 unique.values<-which(!duplicated(paste(x,y)))
 plot( x[unique.values],y[unique.values],xlab="Old File",
 ylab="New File",main=title,pch=4,cex=.5,
 xlim=c(0.1,max.value),ylim=c(0.1,max.value),log="xy")
 lines(c(0.1,max.value),c(0.1,max.value),lwd=3,col="red")
}

plot.heatmap<-function(x,y,title=""){
 minval<-log10(min(c(x,y)))
 maxval<-log10(max(c(x,y)))

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

#test.range<-function(percent,number,df.test,input1,input2,text){
# if (! any(grepl(input1,colnames(df.test))) | ! any(grepl(input2,colnames(df.test)))  ){stop("fields not found")}
# i<-nrow(df.test[which((df.test[[input1]]/df.test[[input2]] < percent & df.test[[input1]]/df.test[[input2]] > 1/percent) | abs(df.test[[input1]]-df.test[[input2]]) <= number),]) #values that changed by <= 5 or +/- 10%
# percent.matching<-100*(i/nrow(df.test))
# return(paste(text,percent.matching))
#}

################################################


newfiles<-system(paste("find ",newdir," -name *projections.txt| sed s@",newdir,"@@g",sep=""),intern=T)
oldfiles<-system(paste("find ",olddir," -name *projections.txt| sed s@",olddir,"@@g",sep=""),intern=T)

cat("new files not in old:\n")
cat(newfiles[which(! newfiles %in% oldfiles)],"\n")
cat("old files not in new:\n")
cat(oldfiles[which(! oldfiles %in% newfiles)],"\n")

testfiles<-newfiles[which(newfiles %in% oldfiles)]
usualfiles<-c('/Hospital/IP/hospital_projections.txt','/Hospital/OP/hospital_projections.txt','/Hospital/hospital_projections.txt','/Office/office_projections.txt','/ASC/asc_projections.txt')
if (length(testfile[which(! testfile %in% usualfiles)] != 0){
 cat("unrecognized files found:\n")
 cat(testfiles[which(! testfiles %in% usualfiles)],"\n")
}


if("/Hospital/IP/hospital_projections.txt" %in% testfiles){

}

if("/Hospital/OP/hospital_projections.txt" %in% testfiles){

}

if("/Hospital/hospital_projections.txt" %in% testfiles){

}

if("/Office/office_projections.txt" %in% testfiles){

}

if("/ASC/asc_projections.txt" %in% testfiles){

}



