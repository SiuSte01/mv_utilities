###This script is designed to run the qa for the monthly masterfile. Once run, a second R script can be run locallyto collect the output into the desired deliverable format. This script is based on the job aid found here: file:///T:\HealthGrades\Documentation\2016_03_31_HealthGrades_MasterFile_and_QA_Reports_Process_GD.docx and should only be run after Ping alerts us that the monthly masterfile has been updated, generally around the 3rd of each month.

#1)	Copy inputs.txt from previous run’s QA to current run. For example, T:\HealthGrades\Monthly_Masterfile\2016-03-01\qa\inputs.txt
#  a.	Within the same folder, reference last month’s QA_Reports_Delivery_For_Bob folder to see reports that are generated for Bob at Healthgrades with delivery
#2)	In inputs.txt update deliverable folder path to current location, YYYY-MM-DD
#Kick off Masterfile QA in any shellbox

old_month="2020-01-01"
new_month="2020-02-01"

dir=`pwd`

#get most recent input
#old_input=/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/$old_month/qa/inputs.txt
#[ ! -e $old_input ] && echo "previous input not found" && exit 1

#copy and update path
#new_dir=/vol/cs/clientprojects/HealthGrades/Monthly_Masterfile/$new_month/qa
#mkdir -p $new_dir
#cp $old_input $new_dir/
#new_input=$new_dir/inputs.txt
#sed -i s@"$old_month"@"$new_month"@g $new_input

#run new qa
#cd $new_dir
#perl /vol/datadev/Statistics/Dilip/MiscProjects/DeltaMFQA/deltamfqa.pl inputs.txt 2>| stderr
#cd $dir

#7)	To generate the fillrates file with the QA_Reports_Delivery_For_Bob folder, do the following:
#a.	Go to T:\Colleen\HG_MF_Test. You’ll see that when Ping runs the HG MF, the latest files will override the old files, which is why there is folder for each previous run within the Dentists, Other, and Physicians subfolders. **Make sure to save the current run before Ping overrides the files for the next month**
#b.	Browse into T:\Colleen\HG_MF_Test\qa_dentists 
#c.	Kick off MF QA script in any shellbox at the location of the inputs.txt file:
#nohup perl /vol/datadev/Statistics/Dilip/MiscProjects/DeltaMFQA/deltamfqa.pl inputs.txt 2>| stderr &
#
#d.	Repeat for: 
#T:\Colleen\HG_MF_Test\qa_other
#T:\Colleen\HG_MF_Test\qa_physicians
#o	Run a total of 3 MF QAs. There is no need to update the inputs file as it always references the latest file in that folder

for i in `echo "Dentists Other Physicians"`
do
 #backup old files before process overwrites
 echo "processing $i"
 mkdir -p /vol/cs/clientprojects/Colleen/HG_MF_Test/$i/$new_month
 [ ! -e /vol/cs/clientprojects/Colleen/HG_MF_Test/$i/$new_month/HMS_Individual_Address* ] && cp /vol/cs/clientprojects/Colleen/HG_MF_Test/$i/*tab /vol/cs/clientprojects/Colleen/HG_MF_Test/$i/$new_month/

 #generate fillrates for dentist, physician, other
 lower=`echo $i | tr '[:upper:]' '[:lower:]'`
 cd /vol/cs/clientprojects/Colleen/HG_MF_Test/qa_$lower
 perl /vol/datadev/Statistics/Dilip/MiscProjects/DeltaMFQA/deltamfqa.pl inputs.txt 2>| stderr 
 mkdir -p /vol/cs/clientprojects/Colleen/HG_MF_Test/qa_$lower/$new_month
 [ ! -e /vol/cs/clientprojects/Colleen/HG_MF_Test/qa_$lower/$new_month/stderr ] && cp /vol/cs/clientprojects/Colleen/HG_MF_Test/qa_$lower/* /vol/cs/clientprojects/Colleen/HG_MF_Test/qa_$lower/$new_month 2> /dev/null
done

cd $dir


