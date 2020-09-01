setwd("T:/Tea_Leaves/2016_02_29_INA_Emdeon/ActivityReport_PxOPOFFASC_Emdeon/KE_QA/PIID_Level_Compare")

bad_records <- read.table("bad_records.txt", header=T, sep="\t", as.is=T, na.strings="")

sink("bad_records_analysis.txt")

#Compute ratio of new to old counts
bad_records$Ratio<-bad_records$Count_Feb/bad_records$Count_Jan

cat("Summary of ratio variable\n")
summary(bad_records$Ratio)

#Show the record with the biggest increase
max_increase<-which.max(bad_records$Ratio)

cat("\n\nLargest ratio value (biggest increase)\n")
bad_records[max_increase,]

#Most frequent ratios
cat("\n\nMost frequent ratio values\n")
ratio_table<-sort(table(bad_records$Ratio),decreasing=T)
print(ratio_table[1:10])

#Most frequent codes
cat("\n\nMost frequent code values\n")
code_table<-sort(table(bad_records$ProcNoDecimal),decreasing=T)
print(code_table[1:10])


sink()