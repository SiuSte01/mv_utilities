Overview
	This script compares old and new activity report files.
	It sums the counts for each code and compares across the two files to see which have changed a lot.

Instructions
	Get your activity report files
		Cut columns ProcNoDecimal and Count from activityreport.txt file for old file (name activityreport_jan.txt)
		Do the same for new file (name activityreport_feb.txt)
	Save R script in the folder with these two new files
	Run comparison script in plsas01 or plr01: R CMD BATCH --vanilla code_count_compare.Run
	Results
		See .Rout file for % good and binned comparisons
		See bad_records.txt for records that have changed more than 10%