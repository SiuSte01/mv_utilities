####make sure to change this back!
#template=/vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_template.csv
#template=/vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_template_short.csv
#template=/vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_template_cpm_only.csv
#template=/vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_template_cpm_only_test.csv
template=/vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_template_cpm_only_20180525.csv

#echo "did you change the template back?";exit 1

fulldate="June 15, 2018"
datenumber="2018_06_15"
rangelower="Oct 2016"
rangeupper="Mar 2018"

while read line
do
type=`echo $line | cut -d "," -f 1`
clientName=`echo $line | cut -d "," -f 2`
username=`echo $line | cut -d "," -f 3`
password=`echo $line | cut -d "," -f 4`
subject=`echo $line | cut -d "," -f 5`
to=`echo $line | cut -d "," -f 6`
cc=`echo $line | cut -d "," -f 7`
name=`echo $line | cut -d "," -f 8`

subject=`echo $subject | sed s/'REPLACE_FULL_DATE'/"$fulldate"/g | sed s/'REPLACE_NAME'/"$clientName"/g`

if [ "$type" == "Main2" ];then
 range="147,214p"
elif [ "$type" == "DTC" ];then
 range="2,47p"
elif [ "$type" == "Main1" ];then
 range="51,143p"
elif [ "$type" == "Type" ];then #excludes header row 
 continue
else
 echo "Type not found"
 continue
fi

echo $type
echo $clientName
echo $username
echo $password
echo $subject
echo $to
echo $cc
echo $name
echo "*****************"

cat /vol/cs/CS_PayerProvider/Ryan/utilities/HG/email_text.txt | sed -n $range | sed s/'REPLACE_NAME'/"$clientName"/g | sed s/'REPLACE_LOGIN'/"$username"/g | sed s/'REPLACE_PASSWORD'/"$password"/g | sed s/'REPLACE_FULL_DATE'/"$fulldate"/g | sed s/'REPLACE_DATE_NUMBER'/"$datenumber"/g | sed s/'REPLACE_RANGE_LOWER'/"$rangelower"/g | sed s/'REPLACE_RANGE_UPPER'/"$rangeupper"/g | mail "$to" -c "$cc" -s "$subject" -- -f 'ryan.hopson@lexisnexisrisk.com'

done < $template





