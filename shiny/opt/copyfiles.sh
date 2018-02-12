
. opt/cloudfunctions.sh
. credentials.sh

add=$1
file=$2

copy_over_jobconfig null  $add $keyfile  $file /udata/workspace/
