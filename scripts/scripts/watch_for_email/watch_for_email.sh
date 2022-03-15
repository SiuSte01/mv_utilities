email_ready=0
dir=`pwd`

[ ! -e $1 ] && echo $1 " not found" && exit

echo "waiting for email signal "$dir/$1

while [ $email_ready == 0 ]
do

#echo "waiting"
grep -q rhopson $1 && email_ready=1

sleep 120

done

command=`grep rhopson $1 | sed s/'rhopson@healthmarketscience.com'/'Ryan.Hopson@lexisnexis.com'/g`

eval $command

