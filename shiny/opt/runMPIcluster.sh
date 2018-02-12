set -e 
#Start MPI Cluster with Cfncluster and run novoalignMPI
#Activate python env 2.7
#source activate gapi
cfncluster list
. opt/cloudfunctions.sh
. credentials.sh
statupdater="Rscript opt/update_jobs.R"

#Make cfncluster template from  a config template
function makeConfig() {
	clustername=$1
	type=$2
	size=$3
	template="templates/clusterconfig.txt"
	perl -e '$file=shift;$t=shift;$size=shift ;open(IN,$file) or die "$!"; while(<IN>) {s/CLUSTERSIZE/$size/;s/ITYPE/$t/;print;}' $template $type $size > $clustername.config
	echo $clustername.config
}
#return head node instance id
function get_headnode () {
	clustername=$1
	headnode=`cfncluster instances $clustername |grep Master |perl -lane 'print $F[1]'`
	echo $headnode
}
#return address of given instance
function get_address(){
	headnode=$1
	add=`aws ec2 describe-instances --instance-ids $headnode|grep ec2 |grep PublicDns |cut -f2 -d: |head -1 |perl -pe 's/,//g;s/"//g;s/\s+//'| perl -pe 's/\s+//'`	
	echo $add
}
#Run setup and installs on cluster
function bootstrap_cluster (){
	sshbase=$1
	scpcmd=$2
	resources=$3
until $sshbase "ls -l" ; do   sleep 15; echo MSG:Trying ssh again; done
echo "MSG:`date` SSH ready"
echo $sshbase 
$sshbase "ls -lh |wc -l"
until $sshbase "qhost" |grep -q ^ip; do echo "MSG: All hosts not ready"; sleep 10; done
$sshbase "qhost" |perl -lane 'BEGIN{print "MSG:Compute Hosts\n"};print "MSG:$_"'
echo "`date` Update, Configuration & Installation"
#unpack the resources
tar -czf $resources resources/* && $scpcmd &&  $sshbase "tar -xzf $resources && echo `date` Resources copied" 
#Do the installation if the novocraft & miniconda folders don't exist
until $sshbase  "ls novocraft miniconda yuminst >/dev/null" ; do 
	echo No install  exists; 
	$sshbase ". resources/bucket.sh; . resources/baseinstalls.sh; install_conda; install_deps; install_novompi ; touch yuminst"
done
}

#default Cluster template
config="clusterconfig.txt"
resources="resrc.tar.gz"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $# -lt 1 ];then
	echo "Usage: $0 <clustername> <genome> <readlocation:s3://path <destination:s3://path> <jobid> <instance size:t2.micro> <cluster size:2>"
	echo "Example: $0 smallclust yeast s3://albertzngs001/testdata/yeast500m s3://ziangscloudruns/jobs/yeastjobcfnjobcfntest-0001 job123 t2.micro 2"
	exit
fi
python --version
echo "`date` $0 Starting script"
cd $DIR
#Define IOs
genome="hg19"
readlocation="s3://ziangscloudruns/samples/09aa685445855a3915136762a39d2b1e.sm/" #Cloud folder with FASTQs
#Command line args
clustername=${1:-"comcluster"}
genome=${2:-"yeast"}
readlocation=${3:-"s3://albertzngs001/testdata/yeast500m"}
destination=${4:-"s3://ziangscloudruns/jobs/yeastjobcfnjobcfntest-0001"}
jobid=${5:-"job00001"}
type=${6:-"t2.micro"} #type of instance
size=${7:-"2"} #cluster size

config=$(makeConfig $clustername $type $size)

echo $config is CFNCluster config for $clustername
SECONDS=0
if cfncluster list |grep -q $clustername ;then 
	echo Cluster exists, not starting it again
	echo "Try deleting $clustername first if you want to restart it"
else 
	#Create the cfncluster
	echo "`date` Update, Cluster initiated, will take ~10minte"
	$statupdater $jobid "creating cluster"
	cfncluster --config $config  create --tags "{ \"pipeline\":\"mpipipeline\",\"infolder\":\"$readlocation\", \"refgenome\":\"$genome\",\"costcenter\":\"biodev\", \"jobid\" : \"$jobid\", \"NGScloud\" : \"GCMCluster\" }" $clustername
	echo "MSG: Cluster $clustername ready, Instances in Cluster"
	echo "`date` Update, cluster ready"

fi
duration=$SECONDS
echo "MSG:CLUSTER CREATION TIME $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
SECONDS=0
$statupdater $jobid "configuring"
cfncluster instances $clustername 
headnode=$(get_headnode $clustername)
add=$(get_address $headnode)
echo "Master Headnode $headnode is $add, Monitor at $add/ganglia"

sshbase="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile ec2-user@$add"
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile $resources ec2-user@$add:~/"

#Install required software
bootstrap_cluster $sshbase $scpcmd $resources
$statupdater $jobid "running"
echo "`date` Update, Running Pipeline tasks || See it live at $add/ganglia"
#Run the alignment & var calling
script="resources/run_mpi_pipeline.sh "
$sshbase "bash $script $genome $readlocation $destination"

echo "`date` Update, Pipeline completed running"

#List all outputs
echo "##########:::Outputs:::################################"
aws s3 ls --recursive --human-readable $destination
echo "#################################################"
duration=$SECONDS
echo "MSG:`date` RUNTIME $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
echo "`date` Update, Deleting cluster"
cfncluster  delete $clustername
