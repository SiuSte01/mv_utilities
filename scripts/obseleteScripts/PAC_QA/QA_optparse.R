#This script is intended to take a csv input that lists every file and field for QA, along with the required QA checks for each. As an example, see /vol/cs/CS_PayerProvider/Ryan/R/data/PAC_input_file.csv.

library("optparse",lib.loc="/home/rhopson/R/x86_64-redhat-linux-gnu-library/3.3")

template_df<-data.frame(
 "INA_PIID2PIID"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/INA_template.txt",
 "INA_relational_PIID2PIID"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/INA_relational_template.txt",
 "INA_relational_PIID2POID"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/INA_relational_PIID2POID_template.txt",
 "PAC_facility"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_facility.txt",
 "PAC_physician"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_physician.txt",
 "PAC_INA"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_INA.txt",
 "PAC_readmit"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_readmit.txt",
 "PAC_SMA_ROP"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_SMA_ROP.txt",
 "PAC_full"="/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/PAC_full.txt"
)

template_list<-colnames(template_df)

option_list <- list(
 #make_option(c("-h", "--help"), action="store_true", default=FALSE,help="Show this help message and exit"),
 make_option(c("-t", "--template"),action="store",type="character",dest="template",default="",help=paste("Choose a template from the following:\n\t\t   ",paste(template_list,collapse="\n\t\t   "),"\n\t\tWhen using this option, your current directory will be used as 'dir' and 'outdir'.",sep="")),
 make_option(c("-i", "--infile"),type="character",dest="infile_arg",default="",help="DO NOT USE if using template arg. Full path to template file"),
 make_option(c("-d", "--dir"),type="character",dest="dir",default="",help="DO NOT USE if using template arg. Directory of files to QA"),
 make_option(c("-o", "--outdir"),type="character",dest="outdir",default="",help="DO NOT USE if using template arg. Output directory for automated QA"),
 make_option(c("-p", "--prefix"),type="character",dest="prefix",default="",help="Optional. Use if indir requires a prefix. Ex: 2016-09-30_*/*")
)

test<-OptionParser(usage = "usage: %prog [options]", option_list = option_list,add_help_option = TRUE, prog = NULL, description = "", epilogue = "")

args<-parse_args(test)
template<-args$template
infile_arg<-args$infile_arg
dir<-args$dir
outdir<-args$outdir
help<-args$help
prefix<-args$prefix

if(template != "" & infile_arg != ""){
 stop("Only one of --template and --infile can be used. See help.")
}else if(template != "" & infile_arg == ""){
 if(dir == ""){dir=getwd()}
 if(outdir == ""){outdir=getwd()}
 if(! template %in% colnames(template_df)){stop("Template not recognized. See help.")}
 infile<-as.character(template_df[[template]][1])
}else if(infile_arg != "" & (dir == "" | outdir == "")){
 stop("If specifing template, 'dir' and 'outdir' must be used as well. See help.")
}else if(infile_arg =="" & template == ""){
 stop("At least one of 'infile' or 'template' must be used. See help.")
}else if(template == "" & infile_arg != ""){
 infile=infile_arg
}

print(infile)
print(dir)
print(outdir)

#stop("testing")

###?fortesting
#infile<-"/HDS/cs/CS_PayerProvider/Ryan/R/PAC_QA/PAC_input_file_short.csv"
#dir<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/test_input"
#outdir<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/test_output"

###?for testing SOC
#infile<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/SOC_input_file.csv"
#dir<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/SOC_test_input"
#outdir<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/SOC_test_output"

###?for testing INA
#infile<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/template_files/INA_template.txt"
#dir<-"/HDS/cs/clientprojects/Fresenius/2016_08_16_Chronic_Kidney_Disease_INA/CKD3_DxCohort/Comb/national_filter"
###dir<-"/HDS/cs/clientprojects/Medtronic_MarketView_ELA/2016_06_22_Neoplasmbone_refresh_INA/Neoplasmbone_Dx_to_Px/Comb/national_filter/"
#outdir<-"/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA/INA_test_output"

###read template
template<-read.csv(infile,stringsAsFactors=F)

###if dir is ./, get full path
if(dir=="./"){dir=getwd()}

#########################################
###adds to template any wildcard paths
#########################################
if(prefix != ""){
 full_names<-paste(prefix,template$File,sep="")
 template$File<-full_names
 head(template)
}

files<-list()
missing_files<-list()
template2<-as.data.frame(matrix(nrow=0,ncol=ncol(template)))
colnames(template2)<-colnames(template)
#cat("---Files Found---","\n")
for (i in unique(template$File)){
 files<-Sys.glob(file.path(dir,i))
# print(files)
 if (length(files) == 0){missing_files<-c(missing_files,i)}
 for (j in files){
  fields<-template[which(template$File==i),c(2:ncol(template))]
  ###?great place to expand fields, check if all fields found
  temp<-data.frame("File"=gsub(paste(dir,"/",sep=""),"",as.character(j)),fields,stringsAsFactors=F)
  template2<-rbind(template2,temp)
 }
}

if(length(missing_files) == length(unique(template$File))){stop("No input files found. If using --template, indir must be current directory. See help.")}
template<-template2

###create outdir
dir.create(paste(outdir,"/automated_QA",sep=""),recursive=TRUE,showWarnings=F)

###set fail file
failfile<-paste(outdir,"automated_QA",paste(Sys.Date(),"_QA_Errors.txt",sep=""),sep="/")
write(paste("*******",Sys.time()),file=failfile,append=T)

#~~~~~~~~~~~~~~~~~~
####read template
#template<-read.csv(infile,stringsAsFactors=F)

###if dir is ./, get full path
#if(dir=="./"){dir=getwd()}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


####################################
###make sure all columns are tests
####################################

tests<-c("Duplicate.check","Fillrate_100","Fillrate","All.X.in.Y","Freq")
if (length(colnames(template)[which(! colnames(template) %in% c(tests,"File","Field"))]) > 0){stop(paste("Check that all template column headers correspond to tests. Current options are:",paste(tests,collapse=", ")))}

sink(paste(outdir,"/automated_QA/",Sys.Date(),"_qa_out.txt",sep=""))
cat("*******")
Sys.time()
cat("---Files Found---","\n")
print(unique(template$File))
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#########################################
###adds to template any wildcard paths
#########################################
#files<-list()
#missing_files<-list()
#template2<-as.data.frame(matrix(nrow=0,ncol=ncol(template)))
#colnames(template2)<-colnames(template)
#cat("---Files Found---","\n")
#for (i in unique(template$File)){
# files<-Sys.glob(file.path(dir,i))
# print(files)
# if (length(files) == 0){missing_files<-c(missing_files,i)}
# for (j in files){
#  fields<-template[which(template$File==i),c(2:ncol(template))]
#  ###?great place to expand fields, check if all fields found
#  temp<-data.frame("File"=gsub(paste(dir,"/",sep=""),"",as.character(j)),fields,stringsAsFactors=F)
#  template2<-rbind(template2,temp)
# }
#}
#if(length(missing_files) == length(unique(template$File))){stop("No input files found. If using --template, indir must be current directory. See help.")}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if(length(missing_files) > 0){
 write(paste("Files listed in template not found. The following are missing:",paste(missing_files,collapse=", ")),file=failfile,append=T)
}
#template<-template2

########################################
###adds to template any wildcard fields
########################################
template2<-as.data.frame(matrix(nrow=0,ncol=ncol(template)))
colnames(template2)<-colnames(template)
for (i in 1:nrow(template)){
 file<-template[i,"File"]
 field<-template[i,"Field"]
 tests<-template[i,which(! colnames(template) %in% c("Field","File"))]
#this next section commented out to force it to search for every field. This rules out files that don't have a * but also may not appear in every version of a product, such as SharedPatientCount in network.txt
# if (! grepl("\\*",field)){
#  row<-data.frame(file,field,tests)
#  colnames(row)<-colnames(template)
#  template2<-rbind(template2,row)
# }else{
  #print(file.path(dir,file))
  filecolnames<-colnames(read.table(file.path(dir,file),sep="\t",header=T,stringsAsFactors=F,quote="",comment.char="", as.is=T, na.strings="",nrows=1))
  if(any(grepl(glob2rx(field),filecolnames))){
   matchingfields<-filecolnames[grep(glob2rx(field),filecolnames)]
   row.names(tests)<-c()
   row<-data.frame(file,matchingfields,tests)
   colnames(row)<-colnames(template)
   template2<-rbind(template2,row)
  }else{
   cat(paste("Error: Matching fields for:",field,"not found."),"\n")
   write(paste("Error: Matching fields for:",field,"not found."),file=failfile,append=T)
   #template<-template[-i,,drop=F]
  }
# }
}
template<-template2

###################
###read in all data
###################
for (i in unique(template$File)){
 #print(i)
 name<-i
 #print(name)
 #print(file.path(dir,i))
 temp<-read.table(file.path(dir,i),sep="\t",header=T,stringsAsFactors=F,quote="",comment.char="", as.is=T, na.strings="")
 assign(name,temp)
}

#####################################
###Main loop
####################################
for (workingfile in unique(template$File)){
 #for (workingtest in colnames(template[3:ncol(template)]){
 name<-workingfile
 assign("temp",get(name))
 cat(paste("Processing file:",name),"\n")

###?needs better output. what check are we doing on what file and field?

#reorder fields to line up w/file
 fileonly<-template[which(template$File == workingfile),]
 fileonly<-fileonly[order(match(fileonly$Field,colnames(temp))),]
 template[which(template$File == workingfile),]<-fileonly

########################
#check for duplicates###
 cat("---Duplicate Fields---\n")
 for (workingfield in template$Field[which(template$File == workingfile & template$Duplicate.check != 'n')]){
   ulength<-length(unique(temp[[workingfield]][which(temp[[workingfield]]!="")]))
   tlength<-length(temp[[workingfield]][which(temp[[workingfield]]!="")])
   #if (length(unique(temp[[workingfield]])) == length(temp[[workingfield]])){
   if (ulength == tlength){
   cat(paste("\tPASS:",workingfield,"is unique."),"\n")
   }else{
   cat(paste("\tFAIL:",workingfield,"is not unique."),"\n")
   write(paste("\tFAIL:",workingfile,":",workingfield,"is not unique."),file=failfile,append=T)
   }
 }
########################
###this whole test should be removed. Can be done in 1 column by entering 100 wherever this should be tested.
#check 100% fillrates###
 if("Fillrate_100" %in% colnames(template)){
  cat("---100% Fillrates---\n")
  for (workingfield in template$Field[which(template$File == workingfile & template$Fillrate_100 != 'n')]){
    if (length(temp[[workingfield]][which(temp[[workingfield]] == "" | is.na(temp[[workingfield]]))])==0){
    cat(paste("\tPASS:",workingfield,"fillrate = 100%."),"\n")
    }else{
    cat(paste("\tFAIL: ",workingfield," fillrate != 100%. Fillrate = ",fillrate,"%",sep=""),"\n")
    }
  }
 }
#######################

#check other fillrates
 cat("---Fillrates---\n")
 for (workingfield in template$Field[which(template$File == workingfile & template$Fillrate != 'n')]){
   fillrate<-(length(temp[[workingfield]][which(temp[[workingfield]] != "" | ! is.na(temp[[workingfield]]))])/nrow(temp))*100
   targetfillrate<-template$Fillrate[which(template$File == workingfile & template$Field == workingfield)]
   if(targetfillrate == 'y'){
   cat("\t",paste(workingfield," fillrate = ",fillrate,"%",sep=""),"\n",sep="")
   }else if(targetfillrate != 'y'){
    if (as.numeric(fillrate) >= as.numeric(targetfillrate)){
     cat(paste("\tPASS: ",workingfield," fillrate >= ",targetfillrate,"%. Fillrate = ",round(fillrate,digits=2),"%",sep=""),"\n")
    }else{
     cat(paste("\tFAIL: ",workingfield," fillrate !>= ",targetfillrate,"%. Fillrate = ",round(fillrate,digits=2),"%",sep=""),"\n")
     write(paste("\tFAIL: ",workingfile,":",workingfield," fillrate !>= ",targetfillrate,"%. Fillrate = ",round(fillrate,digits=2),"%",sep=""),file=failfile,append=T)
    }
   }
  }
#######################

#all x in y
 cat("---All X in Y---\n")
 for (workingfield in template$Field[which(template$File == workingfile & template$All.X.in.Y != 'n')]){
  xiny<-template$All.X.in.Y[which(template$File == workingfile & template$Field == workingfield)]
  matchfile<-strsplit(xiny,split=":")[[1]][1]
  matchfield<-strsplit(xiny,split=":")[[1]][2]
  if(any(grepl(matchfile,ls()))){assign("temp2",get(matchfile))}else{temp2<-read.table(file.path(dir,strsplit(xiny,split=":")[[1]][1]),sep="\t",header=T,stringsAsFactors=F,quote="",comment.char="", as.is=T, na.strings="")}
  missingcount<-length(temp[[workingfield]][which(! temp[[workingfield]] %in% temp2[[matchfield]])])
  foundpercent<-100-(missingcount/nrow(temp)*100)
  if(foundpercent == 100){
   cat(paste("\tPASS: ",name,":",workingfield," in ",matchfile,":",matchfield," percent: ",foundpercent,sep=""),"\n")
  }else{
   failmessage<-paste("\tFAIL: ",name,":",workingfield," in ",matchfile,":",matchfield," percent: ",foundpercent,sep="")
   cat(failmessage,"\n")
   write(failmessage,failfile,append=T)
  }
 }
#######################

#Frequency tables
 cat("---Frequency Tables---\n")
 for (workingfield in template$Field[which(template$File == workingfile & template$Freq != 'n')]){
  cat("\t",workingfile,": ",workingfield,"\n\n",sep="")
  #print(as.data.frame(table(temp[[workingfield]])))
  print(head(as.data.frame(table(temp[[workingfield]]))[order(-as.data.frame(table(temp[[workingfield]]))[["Freq"]]),],n=10L))
  cat("\n")
 }

######################

 cat("\n\n")
}

#test #1 -> unique values
###?update path after testing
#sink(file.path("/vol/cs/CS_PayerProvider/Ryan/R/PAC_QA","test_output","QA_test_out.txt"






