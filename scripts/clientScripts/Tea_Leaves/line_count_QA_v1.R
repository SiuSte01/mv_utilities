######For QAing Tea Leaves, template for QA of other repeating projects
# test if there is at least one argument: if not, return an error

args = commandArgs(trailingOnly=TRUE)

if (length(args) < 6) {
  cat("\nThis script requires 6 arguments:\n  the full path to the directory to be checked\n  the full path to the directory to be checked against\n  the path for the output file\n  the prefix to be used to name columns (i.e. Mar_Apr)\n  the path to the file containing sample paths\n  the highest acceptable percent change\n\n")
  cat("file containing sample paths should be a text file of paths that expand from the folders to individual files, with one path per line. For example:\n/*/*/Comb/*fordelivery.txt\n/*/*/Comb/Filter/*.tab\n/*/payermix.txt\n\n")
  cat("example call: Rscript --vanilla /vol/cs/CS_PayerProvider/Ryan/R/line_count_QA_v1.R /vol/cs/clientprojects/Tea_Leaves/2016_03_31_PxDx_and_INA/2016_03_31_INA_Emdeon /vol/cs/clientprojects/Tea_Leaves/2016_02_29_PxDx_and_INA/2016_02_29_INA_Emdeon /vol/cs/clientprojects/Tea_Leaves/QA_outfiles/test3.csv Mar_Feb /vol/cs/CS_PayerProvider/Ryan/R/sample_paths_test.txt 5\n\n")
  stop("Required args: New_month_dir Old_month_dir Out_file Prefix path_file cutoff_percent", call.=FALSE)
}

New_month_dir=args[1]
Old_month_dir=args[2]
Out_file=args[3]
Prefix=args[4]
path_file=args[5]
cutoff_percent=args[6]

####testing####
#New_month_dir="/vol/cs/clientprojects/Tea_Leaves/2016_03_31_PxDx_and_INA/2016_03_31_INA_Emdeon"
#Old_month_dir="/vol/cs/clientprojects/Tea_Leaves/2016_02_29_PxDx_and_INA/2016_02_29_INA_Emdeon"
#Out_file="/vol/cs/clientprojects/Tea_Leaves/QA_outfiles/test3.csv"
#Prefix="Mar_Feb3"
#sample_path<-"/Cardio_INA/Cardio_INA_DxPx/Comb/*fordelivery.txt"
#path_file<-"/vol/cs/CS_PayerProvider/Ryan/R/sample_paths_test.txt"

paths<-read.table(path_file)
is_new=0

print("Running with args:")
print(paste(New_month_dir,Old_month_dir,Out_file,Prefix,path_file,cutoff_percent))

library(stringr)

if (! file.exists(Out_file)){
  print("Output file not found. If this is not a new project, please check the path")
  is_new=1
} else {
  orig<-read.csv(Out_file,stringsAsFactors=FALSE)
  if(any(grepl(paste(Prefix,"difference",sep="_"),colnames(orig)))){
    stop("Prefix already found. Make sure this hasn't been run.",call.=FALSE)
  }
}

####currently updating this function to do the meat of the work. Need to add: merge new data, get old data, merge old data, compare
defactor<-function(x){
  y<-as.numeric(as.character(x))
  return(y)
}
get_file_info<-function(sample_path){
  #test for any results
  test<-suppressWarnings(system(paste("ls ",New_month_dir,sample_path,sep=""),intern=T,ignore.stderr=T))
  test2<-suppressWarnings(system(paste("ls ",Old_month_dir,sample_path,sep=""),intern=T,ignore.stderr=T))
  if(! is.null(attr(test,"status"))&! is.null(attr(test2,"status"))){
    print(paste("No results found for",sample_path))
	return()
  }
  
  #get counts and file size for new files
  count<-system(paste("wc -l ",New_month_dir,sample_path," | sed s@'",New_month_dir,"'@''@g | awk ' {print $2,$1} '",sep=""),intern=T)
  count<-as.data.frame(str_split_fixed(count," ",2))
  count<-count[which(count$V1 != "total"),]
  colnames(count)<-c("path","count")
  size<-system(paste("ls -l ",New_month_dir,sample_path," | sed s@'",New_month_dir,"'@''@g | awk ' {print $9,$5} '",sep=""),intern=T)
  size<-as.data.frame(str_split_fixed(size," ",2))
  colnames(size)<-c("path","size")
  new<-merge(count,size,all=TRUE)
  
  #get counts and file size for old files
  count_old<-system(paste("wc -l ",Old_month_dir,sample_path," | sed s@'",Old_month_dir,"'@''@g | awk ' {print $2,$1} '",sep=""),intern=T)
  count_old<-as.data.frame(str_split_fixed(count_old," ",2))
  count_old<-count_old[which(count_old$V1 != "total"),]
  colnames(count_old)<-c("path","count_old")
  size_old<-system(paste("ls -l ",Old_month_dir,sample_path," | sed s@'",Old_month_dir,"'@''@g | awk ' {print $9,$5} '",sep=""),intern=T)
  size_old<-as.data.frame(str_split_fixed(size_old," ",2))
  colnames(size_old)<-c("path","size_old")
  old<-merge(count_old,size_old,all=TRUE)
  
  #combine
  comb<-merge(old,new,all=TRUE)
  comb[,2:5]<-apply(comb[,2:5],2,defactor)
  comb$path<-as.character(comb$path)
  
  #check for mismatch in files found!
  missing_from_new<-comb$path[which(is.na(comb$count))]
  missing_from_old<-comb$path[which(is.na(comb$count_old))]
  
  #check percent change
  comb$difference_count<-comb$count-comb$count_old
  comb$difference_size<-comb$size-comb$size_old
  comb$percent_count<-comb$difference_count/comb$count_old*100
  comb$percent_size<-comb$difference_size/comb$size_old*100

  #add in directories and notes
  comb$new_dir<-New_month_dir
  comb$old_dir<-Old_month_dir
  comb$notes<-""
  
  #check for large % changes
  warn_percents<-comb[which(abs(comb$percent_count) > cutoff_percent | abs(comb$percent_size) > cutoff_percent),]
  
  return(list(comb,missing_from_new,missing_from_old,warn_percents))
}

#comb<-get_file_info(sample_path)

comb<-as.data.frame(matrix(nrow=0,ncol=12))
colnames(comb)<-c('path','count_old','size_old','count','size','difference_count',
  'difference_size','percent_count','percent_size','new_dir','old_dir','notes')
warn<-as.data.frame(matrix(nrow=0,ncol=12))
colnames(warn)<-c('path','count_old','size_old','count','size','difference_count',
  'difference_size','percent_count','percent_size','new_dir','old_dir','notes')
missing_from_new<-list()
missing_from_old<-list()

for (i in paths$V1){
	output<-get_file_info(i)
	comb<-rbind(comb,output[[1]])
	warn<-rbind(warn,output[[4]])
	missing_from_new<-c(missing_from_new,output[[2]])
	missing_from_old<-c(missing_from_old,output[[3]])
}

#rename columns to include prefix
colnames(comb)[which(!colnames(comb)=="path")]<-paste(Prefix,colnames(comb)[which(!colnames(comb)=="path")],sep="_")

#update file
if (is_new == 1){
write.csv(comb,Out_file,row.names=F)
}else{
out<-merge(orig,comb,by="path",sort=T,all=T)
write.csv(out,Out_file,row.names=F)
}

#write out warnings
warn_out<-paste(dirname(Out_file),"/",Prefix,"_warnings.csv",sep="")
mn_out<-paste(dirname(Out_file),"/",Prefix,"_missingFromNew.csv",sep="")
mo_out<-paste(dirname(Out_file),"/",Prefix,"_missingFromOld.csv",sep="")
if(nrow(warn) > 0){write.csv(warn,warn_out,row.names=F)}
if(length(missing_from_new) > 0){write.csv(missing_from_new,mn_out,row.names=F)}
if(length(missing_from_old) > 0){write.csv(missing_from_old,mo_out,row.names=F)}

#print warnings to screen
cat("\nmissing from new month:")
print(missing_from_new)
cat("\nmissing from old month:")
print(missing_from_old)
if(nrow(warn) > 0){cat(paste("\nPercent change > threshold found. For details, check",warn_out,"\n"))}


