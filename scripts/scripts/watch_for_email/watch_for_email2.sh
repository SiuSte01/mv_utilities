job=$1
subject=$2

while [ -e /proc/$job ]; do sleep 60; done
echo -e "Process id $job\n$subject has completed" | mail "Ryan.Hopson@lexisnexis.com" -s "$subject has completed"


