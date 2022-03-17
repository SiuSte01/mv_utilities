#.libPaths("C:/Users/rhopson/Documents/R/R-3.3.2/library")
library("xlsx")
#settings
month<-"January"
year<-"2019"
old_deliverable<-"2018-12-01"
new_deliverable<-"2019-01-01"
new_month<-paste(month,year,sep=" ")

#outpaths
monthpath<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",new_deliverable,"/delivery",sep="")
path2<-paste(monthpath,"/",month,"_HG_MasterFile_QA_report.xlsx",sep="")
path3<-paste(monthpath,"/Fill_Rates_by_Practitioner_Type",".xlsx",sep="")
path4<-paste(monthpath,"/PIID_Address_Drop",".xlsx",sep="")

#old files
oldfolder<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",old_deliverable,"/delivery/",sep="")
path<-paste(oldfolder,list.files(oldfolder,pattern="HG_MasterFile_QA_report.xlsx"),sep="")
fr_path<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",old_deliverable,"/delivery/Fill_Rates_by_Practitioner_Type.xlsx",sep="")
drop_path<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",old_deliverable,"/delivery/PIID_Address_Drop.xlsx",sep="")

#new inputs
folder<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",new_deliverable,"/qa",sep="")
colleen_path<-"/vol/cs/clientprojects/Colleen/HG_MF_Test"
drop_new_path<-paste("/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/",new_deliverable,"/milestones/delta/HMS_Individual_Address_Drop_Rpt.tab",sep="")

####start####

###update first sheet####
s1<-xlsx::read.xlsx(path,1,header=F)
s1_new<-read.table(file.path(folder,"qaresults.tab"),fill=TRUE,row.names=NULL,sep="~",stringsAsFactors = F,blank.lines.skip = F,quote = "")
s1_new[1,1]<-"Column separator = |"
s1_new$V2<-""
s1_new$V2[1]<-"|"
s1_new<-rbind(data.frame("V1"=new_month,"V2"=""),s1_new)
if(nrow(s1)>nrow(s1_new)){
  temp<-data.frame(matrix(nrow=abs(nrow(s1)-nrow(s1_new)),ncol=ncol(s1_new)))
  colnames(temp)<-colnames(s1_new)
  s1_new<-rbind(s1_new,temp)
}
if(nrow(s1_new)>nrow(s1)){
  temp<-data.frame(matrix(nrow=abs(nrow(s1_new)-nrow(s1)),ncol=ncol(s1)))
  colnames(temp)<-colnames(s1)
  s1<-rbind(s1,temp)
}


s1_comb<-cbind(s1,s1_new)
xlsx::write.xlsx(s1_comb,path2,append=TRUE,sheetName = "NEW_qaresults",showNA = F,col.names = F,row.names = F)

###update second sheet#####
s2<-xlsx::read.xlsx(path,2,header=F,colClasses = "character",stringsAsFactors=F)
s2_new<-read.table(file.path(folder,"qareport.txt"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,quote = "")
#s2_new<-rbind(data.frame("V1"="","V2"="","V3"=new_month),s2_new)

###below is commented out because qareport.txt seems to already have percents
#convert numbers to percents
#value_columns<-grep("Number",s2[2,])+1
#for (i in value_columns){
#  value_rows<-grep("Fill",s2[,(i-1)])
#  #print(s2[value_rows,i])
#  s2[value_rows,i]<-paste(as.character(s2[value_rows,i]*100),"%",sep="")
#}

s2_comb<-merge(s2,s2_new,by.x=c("X1","X2"),by.y=c("V1","V2"),all=T)
s2_comb[1,ncol(s2_comb)]<-new_month
xlsx::write.xlsx(s2_comb,path2,append=TRUE,sheetName = "NEW_QA_report",showNA = F,col.names = F,row.names = F)

###update third sheet####
#xlsx::read.xlsx skips empty columns, xlsx::read.xlsx2 skips rows missing first value. Have to use both
#s3<-xlsx::read.xlsx2(path,3,header=F,colClasses = "character",stringsAsFactors=F)
#s3.1<-xlsx::read.xlsx(path,3,header=F,colClasses = "character",stringsAsFactors=F)
#s3<-cbind(s3,s3.1[,ncol(s3.1)-1])
s3<-xlsx::read.xlsx(path,3,header=F,colClasses = "character",stringsAsFactors=F)
s3_new<-read.table(file.path(folder,"ValuesFor_PRACTITIONER_TYPE_In_HMS_Individuals_uniq_scid.tab"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
s3_new<-rbind(data.frame("V1"=NA,"V2"=new_month),s3_new)
#s3_comb<-cbind(s3,"",s3_new)
s3_comb<-merge(s3,s3_new,by.x=c("X1"),by.y=c("V1"),all=T)
s3_comb<-s3_comb[c(nrow(s3_comb),order(as.numeric(s3_comb[(1:(nrow(s3_comb)-1)),2]),decreasing=T)),]

xlsx::write.xlsx(s3_comb,path2,append=TRUE,sheetName = "Check Pract Types",showNA = F,col.names = F,row.names = F)

###update fourth sheet####
#xlsx::read.xlsx skips empty columns, xlsx::read.xlsx2 skips rows missing first value. Have to use both
#s4<-xlsx::read.xlsx2(path,4,header=F,colClasses = "character",stringsAsFactors=F)
#s4.1<-xlsx::read.xlsx(path,4,header=F,colClasses = "character",stringsAsFactors=F)
#s4<-cbind(s4,s4.1[,ncol(s4.1)])
s4<-xlsx::read.xlsx(path,4,header=F,colClasses = "character",stringsAsFactors=F)
s4_new<-read.table(file.path(folder,"ValuesFor_ADDRESS_RANK_In_HMS_Individual_Address.tab"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
s4_new<-rbind(data.frame("V1"=NA,"V2"=new_month),s4_new)
s4_comb<-merge(s4,s4_new,by.x=c("X1"),by.y=c("V1"),all=T)
s4_comb<-s4_comb[c(nrow(s4_comb),1:(nrow(s4_comb)-1)),]

xlsx::write.xlsx(s4_comb,path2,append=TRUE,sheetName = "Address Ranks",showNA = F,col.names = F,row.names = F)

###update fifth sheet####
#xlsx::read.xlsx skips empty columns, xlsx::read.xlsx2 skips rows missing first value. Have to use both
#s5<-xlsx::read.xlsx2(path,5,header=F,colClasses = "character",stringsAsFactors=F)
#s5.1<-xlsx::read.xlsx(path,5,header=F,colClasses = "character",stringsAsFactors=F)
#s5<-cbind(s5,s5.1[,ncol(s5.1)])
s5<-xlsx::read.xlsx(path,5,header=F,colClasses = "character",stringsAsFactors=F)
s5_new<-read.table(file.path(folder,"ValuesFor_DERIVED_SPEC1_In_HMS_Individuals_uniq_scid.tab"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
s5_new<-rbind(data.frame("V1"=NA,"V2"=new_month),s5_new)
#if(nrow(s5)>nrow(s5_new)){s5_new<-rbind(s5_new,as.data.frame(matrix(nrow=(nrow(s5)-nrow(s5_new)),ncol=2)))}
#s5_comb<-cbind(s5,"",s5_new)
s5_new$V1[which(s5_new$V1=="")]<-"Blank"
s5_comb<-merge(s5,s5_new,by.x=c("X1"),by.y=c("V1"),all=T)
s5_comb<-s5_comb[c(nrow(s5_comb),order(as.numeric(s5_comb[(1:(nrow(s5_comb)-1)),2]),decreasing=T)),]

xlsx::write.xlsx(s5_comb,path2,append=TRUE,sheetName = "DerivedSpecialty",showNA = F,col.names = F,row.names = F)

###update sixth sheet####
#xlsx::read.xlsx skips empty columns, xlsx::read.xlsx2 skips rows missing first value. Have to use both
#s6<-xlsx::read.xlsx2(path,6,header=F,colClasses = "character",stringsAsFactors=F)
#s6.1<-xlsx::read.xlsx(path,6,header=F,colClasses = "character",stringsAsFactors=F)
#s6<-cbind(s6,s6.1[,ncol(s6.1)])
s6<-xlsx::read.xlsx(path,6,header=F,colClasses = "character",stringsAsFactors=F)
s6_new<-read.table(file.path(folder,"ValuesFor_FACTYPE_In_HMS_Organizations.tab"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
s6_new<-rbind(data.frame("V1"=NA,"V2"=new_month),s6_new)

s6_new$V1[which(s6_new$V1=="")]<-"Blank"
s6_comb<-merge(s6,s6_new,by.x=c("X1"),by.y=c("V1"),all=T)
s6_comb<-s6_comb[c(nrow(s6_comb),order(as.numeric(s6_comb[(1:(nrow(s6_comb)-1)),2]),decreasing=T)),]

xlsx::write.xlsx(s6_comb,path2,append=TRUE,sheetName = "Fact Types",showNA = F,col.names = F,row.names = F)

###update seventh sheet####
#xlsx::read.xlsx skips empty columns, xlsx::read.xlsx2 skips rows missing first value. Have to use both
#s7<-xlsx::read.xlsx2(path,7,header=F,colClasses = "character",stringsAsFactors=F)
#s7.1<-xlsx::read.xlsx(path,7,header=F,colClasses = "character",stringsAsFactors=F)
#s7<-cbind(s7,s7.1[,ncol(s7.1)])
s7<-xlsx::read.xlsx(path,7,header=F,colClasses = "character",stringsAsFactors=F)
s7_new<-read.table(file.path(folder,"ValuesFor_HMS_SPEC1_In_HMS_Individuals_uniq_scid.tab"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
s7_new<-rbind(data.frame("V1"=NA,"V2"=new_month),s7_new)
#if(nrow(s7)>nrow(s7_new)){s7_new<-rbind(s7_new,as.data.frame(matrix(nrow=(nrow(s7)-nrow(s7_new)),ncol=ncol(s7_new))))}
#s7_comb<-cbind(s7,"",s7_new)

s7_new$V1[which(s7_new$V1=="")]<-"Blank"
s7_comb<-merge(s7,s7_new,by.x=c("X1"),by.y=c("V1"),all=T)
s7_comb<-s7_comb[c(nrow(s7_comb),order(as.numeric(s7_comb[(1:(nrow(s7_comb)-1)),2]),decreasing=T)),]

xlsx::write.xlsx(s7_comb,path2,append=TRUE,sheetName = "HMS_Spec",showNA = F,col.names = F,row.names = F)

###update fill rates####
#dentists
frdent<-xlsx::read.xlsx2(fr_path,1,header=F,colClasses = "character",stringsAsFactors=F)
frdent_new<-read.table(file.path(colleen_path,"qa_dentists","qareport.txt"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")

frdent_new<-rbind(data.frame("V1"="File","V2"="Field","V3"=new_month),frdent_new)
frdent_comb<-merge(frdent,frdent_new,by.x=c("X1","X2"),by.y=c("V1","V2"),all=T)

xlsx::write.xlsx(frdent_comb,path3,append=TRUE,sheetName = "Dentists",showNA = F,col.names = F,row.names = F)

#pysicians
frphys<-xlsx::read.xlsx2(fr_path,2,header=F,colClasses = "character",stringsAsFactors=F)
frphys_new<-read.table(file.path(colleen_path,"qa_physicians","qareport.txt"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")

frphys_new<-rbind(data.frame("V1"="File","V2"="Field","V3"=new_month),frphys_new)
frphys_comb<-merge(frphys,frphys_new,by.x=c("X1","X2"),by.y=c("V1","V2"),all=T)

xlsx::write.xlsx(frphys_comb,path3,append=TRUE,sheetName = "Physicians",showNA = F,col.names = F,row.names = F)

#all others
froth<-xlsx::read.xlsx2(fr_path,3,header=F,colClasses = "character",stringsAsFactors=F)
#froth had a blank last line, this next part checks for that and removes it if necessary
if(all(froth[nrow(froth),]=="")){froth<-froth[c(1:(nrow(froth)-1)),]}
froth_new<-read.table(file.path(colleen_path,"qa_other","qareport.txt"),fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")

froth_new<-rbind(data.frame("V1"="File","V2"="Field","V3"=new_month),froth_new)
froth_comb<-merge(froth,froth_new,by.x=c("X1","X2"),by.y=c("V1","V2"),all=T)

xlsx::write.xlsx(froth_comb,path3,append=TRUE,sheetName = "All_Others",showNA = F,col.names = F,row.names = F)




###update address drops####
drop_new<-read.table(drop_new_path,fill=TRUE,row.names=NULL,sep="\t",stringsAsFactors = F,blank.lines.skip = F,colClasses = "character",quote = "")
file.copy(drop_path, path4)

###file to large to use java - need to use openxlsx because it doesn't need java
library(openxlsx)
test<-openxlsx::loadWorkbook(path4)
openxlsx::addWorksheet(test,new_month)
openxlsx::writeData(test,new_month,drop_new,colNames=F)
openxlsx::saveWorkbook(test,path4,overwrite=T)


