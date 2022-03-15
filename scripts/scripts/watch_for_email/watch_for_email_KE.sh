job=$1
subject=$2
email=$3

while [ -e /proc/$job ]; do sleep 60; done
echo -e "Process id $job\n$subject has completed" | mail "$email" -s "$subject has completed"


