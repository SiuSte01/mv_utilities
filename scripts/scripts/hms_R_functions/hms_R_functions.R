#read.hms<-function(x){
# return(read.csv(x,sep="\t",stringsAsFactors=F,header=T,quote="",comment.char="" ))
#}

write.hms<-function(x,y,row.names=F,sep="\t",quote=F,na="",...){
 write.table(x,y,row.names=row.names,sep=sep,quote=quote,na=na,...)
}

read.hms<-function(x,y=c("CODES","ZIP","ZIP4","ZIP_1","ZIP4_1","ZIP_2","ZIP4_2","CODE"),stringsAsFactors=F,header=T,quote="",comment.char="",sep="\t",scanlen=500,...){
 #x=file name,y=code column name
 headset<-read.csv(x,sep=sep,stringsAsFactors=stringsAsFactors,header=header,quote=quote,comment.char=comment.char,nrows=scanlen)
 classes<-sapply(headset,class)
 #print(classes)
 classes[classes=="logical"]<-"character"
 classes[classes=="integer"]<-"numeric"
 classes[names(classes) %in% y] <- "character"
 return(read.csv(x,sep=sep,stringsAsFactors=stringsAsFactors,header=header,quote=quote,comment.char=comment.char,colClasses = classes,...))
}

oracle<-function(){
suppressMessages(library(ROracle))
drv <<- dbDriver("Oracle")
con <<- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")

print('query<-paste("SELECT a.Setting, SUM(Claim_Cnt) FROM Claims_Aggr.Claims_Smry_Dx_Mvw a WHERE a.code in (",codes,") group by a.setting",sep="")')
print("fetch(dbSendQuery(con, query))")

}


read.hms2<-function(x,y=c("CODES","ZIP","ZIP4","ZIP_1","ZIP4_1","ZIP_2","ZIP4_2","CODE"),stringsAsFactors=F,header=T,quote="",comment.char="",sep="\t",scanlen=500,...){
 #x=file name,y=code column name
 headset<-read.csv(x,sep=sep,stringsAsFactors=stringsAsFactors,header=header,quote=quote,comment.char=comment.char,nrows=scanlen)
 classes<-sapply(headset,class)
 #print(classes)
 classes[classes=="logical"]<-"character"
 classes[classes=="integer"]<-"numeric"
 classes[names(classes) %in% y] <- "character"
 test=1
 while (test==1){
  outdata<-tryCatch({read.csv(x,sep=sep,stringsAsFactors=stringsAsFactors,header=header,quote=quote,comment.char=comment.char,colClasses = classes,...)
  }, warning = function(w) {
   scanlen<-scanlen+500
  }, finally = {
   test=0
  }
  )

 }
 return(outdata)
}


