#Name of Dx column
dx_column<-"Dx_PRACTITIONER_TERR_RANK"
cutoff<-2

#Get current directory
dir<-getwd()
setwd(dir)
source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

#Read in individuals_sample file
indivs <- read.hms("individuals_sample.tab")

#Check that Dx column exists in indivs file
if(dx_column %in% colnames(indivs)=='FALSE')
{cat("Warning: Column",dx_column,"not found in data.")}

#Figure out which columns are the rank columns because number of rank columns may change
rank_cols<-grep("TERR_RANK",colnames(indivs),value = T)
rank_cols_no_dx<-grep(dx_column,rank_cols,invert = T,value=T)
num_rank_col<-length(rank_cols_no_dx)

#Figure out which column is the Dx column
dx_column_num<-grep(dx_column,colnames(indivs))

#Create new columns indicating if each non-Dx rank is blank (F) or not (T)
for (i in rank_cols_no_dx){
  na_i<-!is.na(indivs[rank_cols_no_dx])
  colnames(na_i)<-paste0(colnames(na_i),"_NEW")
###?this will break in a loop, because each time indivs_updated will be overwritten with indivs,na_i
  indivs_updated<-cbind(indivs,na_i)
}

#Cut only the columns with PIID and true/false RANK columns
indivs_tf<-indivs_updated[,(grep('_NEW|HMS_PIID', names(indivs_updated)))]

#Create sum so that anyone with all blanks for non-Dx ranks has sum of zero
sums<-rowSums(indivs_tf[,(2:ncol(indivs_tf))])
indivs_tf_sums<-cbind(indivs_tf,sums)

#Merge with original dataset
indivs_merge<-merge(x=indivs,y=indivs_tf_sums)

#Remove rows where Dx column is rank 1 and all other ranks are blank
remove<-indivs_merge[which(indivs_merge[dx_column_num]=<1 & indivs_merge$sums==0),]
indivs_final<-indivs[which(!indivs$HMS_PIID %in% remove$HMS_PIID),]
# indivs_final<-indivs_filtered[,c(1:18,20,21,19)]


#removed the below so this will work with counts. Assumes column order is already correct.
##Get number of all rank columns
#rank_cols_num<-grep("TERR_RANK",colnames(indivs))
##Pull out dx column separately (we want that to be the last column in output)
#rank_cols_num2<-rank_cols_num[which(!rank_cols_num %in% dx_column_num)]
#rank_cols_num_order<-c(rank_cols_num2,as.integer(dx_column_num))
#Final column order
###? think this will break when we have counts included.
#order<-c(1:17,rank_cols_num_order)
#indivs_final<-indivs_filtered[order]


write.hms(indivs_final,"individuals_sample_lowfiltered_TEST.tab")

#filter pxdx
pxdx<-read.hms("pxdx_sample.tab")
pxdx_final<-pxdx[which(pxdx$HMS_PIID %in% indivs_final$HMS_PIID),]

write.hms(pxdx_final,"pxdx_sample_lowfiltered_TEST.tab")

