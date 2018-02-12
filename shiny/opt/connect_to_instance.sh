
. credentials.sh

add=$1

sshbase="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile ec2-user@$add"


$sshbase
