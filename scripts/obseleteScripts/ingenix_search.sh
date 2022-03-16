###this first command stores a login cookie. It needs to be run the first time we run this script, but not again if run multiple times.
#wget --user-agent="Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36" --keep-session-cookies --save-cookies cookies.txt --post-data "_a=logon&forwardURL=/&userName=HMS002&passwordEnforceLogon=false&password=Summer2016&rememberMe=true&btn_login.x=30&btn_login.y=11&forwardURL=/" --no-check-certificate https://www.encoderprofp.com/epro4payers/logon.do
[ $# != 2 ] && printf 'This script requires exactly 2 arguments: the path to a list of HCPCS codes, and a bucket name.' && exit 2
[ ! -e cookies.txt ] && printf 'Login cookie not found. Before searching, you must log in to ingenix by running the following command from the command line:\n\nwget --output-document=/dev/null --user-agent="Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36" --keep-session-cookies --save-cookies cookies.txt --post-data "_a=logon&forwardURL=/&userName=HMS002&passwordEnforceLogon=false&password=Fall2016&rememberMe=true&btn_login.x=30&btn_login.y=11&forwardURL=/" --no-check-certificate https://www.encoderprofp.com/epro4payers/logon.do\n' && exit 1

current=`pwd`

[ ! -w $current ] && printf "You must have write permissions to the current directory: $current\n\n" && exit 3

tempnum=$RANDOM

#for i in `echo 33264 33208`
#for i in `cat card_codes.txt | cut -f 1`
for i in `cat $1`
do
 echo "**** $i"

 wget --output-document="$tempnum"_temp.html --no-check-certificate --user-agent="Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36" --load-cookies cookies.txt "https://www.encoderprofp.com/epro4payers/crosscodesHandler.do?_k=101*"$i"&_a=listRelated&codeType=2"

# wget --output-document="$tempnum"_temp.html --no-check-certificate --user-agent="Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36" --load-cookies cookies.txt "https://www.encoderprofp.com/epro4payers/crosscodesHandler.do?_k=101*"$i"&_a=listRelated&codeType=32768"

 for code in `grep 'id="crosswalkLineTable:' "$tempnum"_temp.html | grep -v ':"' | cut -d ":" -f 2 | cut -d '"' -f 1`
 do
  echo $i,$code >> ingenix_output.txt
 done

 sleep 10

done

printf "BUCKET\tCODE\tCODE_TYPE\tCODE_SCHEME\n" > icd9_ingen_codes.txt

for icd in `cat ingenix_output.txt | cut -d "," -f 2 | sort -u`
do 

 printf "$2\t$icd\tpx\tICD9\n" >> icd9_ingen_codes.txt

done

###logout
[ -e cookies.txt ] && wget --output-document=/dev/null --no-check-certificate --user-agent='Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36' --load-cookies cookies.txt https://www.encoderprofp.com/epro4payers/logon.do?_a=logout

rm -f $tempnum"_temp.html"
rm -f cookies.txt

