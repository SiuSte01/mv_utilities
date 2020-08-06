#Read in files to compare

old_file_path <- "T:/Tea_Leaves/2018_01_31_PxDx_and_INA/2018_01_31_PxDx_Emdeon/Ortho_Dx_PxDx_ignore/Ortho_Hand_Wrist_dx_ip/milestones/organizations.tab"
new_file_path <- "T:/Tea_Leaves/2018_02_28_PxDx_and_INA/2018_02_28_PxDx_Emdeon/Ortho_Dx_PxDx_ignore/Ortho_Hand_Wrist_dx_ip/milestones/organizations.tab"

oldfile  <-  read.table(old_file_path, header=T, sep="\t", quote="", comment.char="", as.is=T,na.strings=c("","*"))
oldfile_edit <- read.table(new_file_path, header=T, sep="\t", quote="", comment.char="", as.is=T, na.strings=c("","*"))

#Cut down to column names only
colnames_oldfile<-colnames(oldfile)
colnames_newfile<-colnames(oldfile_edit)


#sink("header_check.txt")
cat("Do the files have an equal number of columns?\n")
identical(ncol(oldfile),ncol(oldfile_edit))
cat("\n\n")

#Are column names identical?
header_check <- function(A,B){
  if (!isTRUE(all.equal(A,B))){
    mismatches <- paste(which(A !=B), collapse = ",")
    cat("ERROR: The files do not match at the following columns: ", mismatches)
  } else {
    message("The column headers are identical.")
  }
}

header_check(colnames_oldfile,colnames_newfile)

#Print names of mismatching columns (if applicable)

if (!isTRUE(all.equal(colnames_oldfile,colnames_newfile))){
  mismatches <- which(colnames_oldfile != colnames_newfile)
  cat("\n\n")
  cat("Mismatched column names (OLD file):\n")
  colnames_oldfile[mismatches]
}

if (!isTRUE(all.equal(colnames_oldfile,colnames_newfile))){
  mismatches <- which(colnames_oldfile != colnames_newfile)
  cat("\n\n")
  cat("Mismatched column names (NEW file):\n")
  colnames_newfile[mismatches]
}
#sink()
