
###for testing
#i<-"T://Erlanger/2016_07_29_Delivery/PxDx_INA_FlatFiles/2016_07_29_Erlanger_GIPx_PxDx_INA"

########SET THESE########

accessdelivery<-"T://BPL/2017_03_01_SS_IG_Octagam_Gammagard_Projections/SOC"
filepaths<-"T://BPL/2017_03_01_SS_IG_Octagam_Gammagard_Projections/SOC"
name<-"auto"

#filepaths<-"T://Celgene/2016_09_06_SS_Systems_Of_Care/Hematology_Px/SOC2/milestones" #path to inputs
#accessdelivery<-"K://CS_PayerProvider/Ryan/accesstesting/2016_09_06_SS_Systems_Of_Care2_MVHS" #path to output
#name<-"Hematology_Px" #set this to "auto" in order to name based on filestructure. set to anything else for user defined name


########################
#inputfile<-"K://CS_PayerProvider/Ryan/utilities/templates/new_prod_test_mvhs.txt" #mvhs template file
inputfile<-"K://CS_PayerProvider/Ryan/utilities/templates/new_prod_test.txt" #template file. do not change for SOC product
########################



.libPaths("K://CS_PayerProvider/Ryan/rlibbackup/library")
library("RODBC")

#####define functions######
convertcolumns<-function(x,y){
  for (search in y){
    x[,grep(search,colnames(x))]<-sapply(x[,grep(search,colnames(x))],as.numeric)
  }
  return(x)
}
read.hms<-function(path,namestring){
  temp<-read.table(Sys.glob(paste(path,namestring,sep="/")),
                   header=T,sep="\t",quote="",comment.char="",colClasses="character")
  assign("filep",strsplit(basename(Sys.glob(paste(path,namestring,sep="/"))),split="\\.")[[1]][1],envir=.GlobalEnv)
  return(temp)
}
############################


dir.create(accessdelivery)
if(! dir.exists(accessdelivery)){stop("delivery folder not created. check path.",print(accessdelivery))}
if(! file.exists(inputfile)){stop("input file not found. check path.",print(inputfile))}
if(length(Sys.glob(filepaths))==0){stop("filepaths do not exist. check path.",print(filepaths))}

directions<-read.table(inputfile,sep="\t",header=T)


for (i in Sys.glob(filepaths)){
  #name<-basename(i)
  if(name == "auto"){name<-unlist(strsplit(i,split="/"))[length(unlist(strsplit(i,split="/")))-2]}
  #accessdelivery<-paste(paste(unlist(strsplit(i,split="/"))[1:length(unlist(strsplit(i,split="/")))-1],collapse="/"),"/delivery/SOC",sep="") #this is the way we want to run this, but permissions are an issue
  if(! dir.exists(accessdelivery)){stop("delivery folder not created. check path.",print(accessdelivery))}
  outpath<-paste(accessdelivery,"/",name,".mdb",sep="")
  file.copy("K://CS_PayerProvider/Ryan/utilities/templates/empty_access_template.mdb",outpath)
  
  ch<-odbcConnectAccess2007(outpath)
  
  for (j in seq(1:nrow(directions))){
    pattern<-directions[j,1]
    if(file.exists(paste(i,pattern,sep="/"))){
     print(as.character(pattern))
     terms<-strsplit(as.character(directions[j,2]),split=",")
     temp<-read.hms(i,pattern)
     if(directions[j,2] != ""){temp<-convertcolumns(temp,terms[[1]])}
     sqlSave(ch,temp,filep,rownames=F)
    }else{
      print(paste("File not found:",pattern))
    }
  }
  
  odbcCloseAll()
}
