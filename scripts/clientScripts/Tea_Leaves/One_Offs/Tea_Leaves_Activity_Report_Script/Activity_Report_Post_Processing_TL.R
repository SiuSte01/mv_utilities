dir<-getwd()

path_act_report<-paste(dir,"activity_breakout.txt",sep="/")

act_report<-read.delim(path_act_report,header=T,sep="\t", quote="",colClasses="character")

act_report_no_desc<-act_report[,c(1:4,6)]

code_desc_with_dupes<-act_report[,c(2,4,7)]

unique_desc<-unique(code_desc_with_dupes)

write.table(unique_desc,"code_description.txt",sep="\t",quote=FALSE,row.names=FALSE,na="")

write.table(act_report_no_desc,"activityreport_nodesc.txt",sep="\t",quote=FALSE,row.names=FALSE,na="")

