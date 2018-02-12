
#### Cloud launch and monitor functions #####

function command_exists () {
    type "$1" &> /dev/null ;
}


function wait_for_instance (){
	instance_id=$1
until aws ec2 describe-instance-status --instance-ids $instance_id --filters Name=instance-status.reachability,Values=passed | grep -q passed
do
    echo "MSG:The instance SSH status $instance_id is not ready, waiting ..."
    sleep 35
done

}


function sshec2 () {
        sampleid=$1
        type=$2
        ami=$3
        seckey=$4
	volsize=$5
	userdata=$6
        #here is where i put my sysadmin bootstrap actions
	 startup_script="file://$userdata"
        #Launch a machine
        #echo Sample=$sampleid AMI=$ami Type=$type 
    #echo "##EC2 params: AMI=$ami,InstanceSize=$type,Size=$volsize"
    ukey=`perl -e 'use strict; use warnings;for (1 .. 4) {printf "%08X", rand(0xffffffff);} print"\n"'`
        #echo $ukey
 	iam="s3access-profile"
	iam="cloudsuper"
	
	#Mounts on root device	
	snapid="snap-f2d4ec0c"
	altvolume=file://filemapping.json
	
	#old volume
	volume="[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$volsize,\"DeleteOnTermination\":true}}]"
	
	aws ec2 run-instances   --image-id $ami \
                                --iam-instance-profile Name="$iam" \
                                 --count 1 \
                                --instance-type $type \
                                 --key-name $seckey \
                                 --security-groups default \
                                --user-data $startup_script \
                                --block-device-mappings  $volume  > $ukey.awsresponse.json

        instance_id=`cat $ukey.awsresponse.json | jq .Instances[].InstanceId |perl -pe 's/"//g'`
	#rm $ukey.awsresponse.json |
         echo $instance_id
}


function testingsshec2v2 () {
        sampleid=$1
        type=$2
        ami=$3
        seckey=$4
	volsize=$5
	userdata=$6
        #here is where i put my sysadmin bootstrap actions
	 startup_script="file://$userdata"
        #Launch a machine
        #echo Sample=$sampleid AMI=$ami Type=$type 
    #echo "##EC2 params: AMI=$ami,InstanceSize=$type,Size=$volsize"
    ukey=`perl -e 'use strict; use warnings;for (1 .. 4) {printf "%08X", rand(0xffffffff);} print"\n"'`
        #echo $ukey
 	iam="s3access-profile"
	iam="cloudsuper"
	
	#Mounts on root device	
	snapid="snap-f2d4ec0c"
	altvolume=file://filemapping.json
	
	#Add subnet and vpc
	aws ec2 run-instances   --image-id $ami \
                                --iam-instance-profile Name="$iam" \
                                 --count 1 \
                                --instance-type $type \
                                 --key-name $seckey \
                                 --security-groups default \
                                --user-data $startup_script \
                                --block-device-mappings  $altvolume  > $ukey.awsresponse.json

        instance_id=`cat $ukey.awsresponse.json | jq .Instances[].InstanceId |perl -pe 's/"//g'`
	#rm $ukey.awsresponse.json |
         echo $instance_id
}


function addDevice () {
	instanceid=$1
	aws ec2 modify-instance-attribute --instance-id $instanceid --block-device-mappings file://filemapping.json
	
}



#Launch simple test pipeline
function launch_test_pipeline () {
instance_id=$1
add=$2
keyfile=$3
echo Server DNS : $add
aws ec2 describe-instance-status --instance-id $instance_id --output text 
sshcmd="ssh   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile ec2-user@$add"
$sshcmd  "df -h; ls -l  /udata/workspace/ ; mkdir -p /udata/workspace/datarun; ls -l ~/; echo A sequence; seq 1 20; sleep 10" 
echo `date` Pipeline script done

}

function copy_over_postrun (){
instance_id=$1
add=$2
keyfile=$3
di="/udata/workspace/datarun/outputs/postrun"
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  'ec2-user@$add:$di/*.txt'  ./www/jbs/ps/"
echo "MSG: `date` Attempting copy of Postrun"
$scpcmd 
echo `date` Copy command done
}


#Copy over job config file to home directory
function copy_over_jobconfig () {
instance_id=$1
add=$2
keyfile=$3
filetocopy=$4
remotefile=`basename $filetocopy`
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  $filetocopy ec2-user@$add:~/$remotefile"
echo "MSG:`date` Copyingy  Job Config"
$scpcmd  
echo `date` Copy command done
}

#Make resources  as inputs for pipeline
function copy_over_jobenv () {
instance_id=$1
add=$2
keyfile=$3
filetocopy=$4
remotefile=`basename $filetocopy`
jobenv=`echo $filetocopy | sed 's/.json/.sh/'`
perl opt/json_To_env.pl $filetocopy > $jobenv
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  $jobenv ec2-user@$add:~/jobenv.sh"
echo Attempting copy of Job Env  $jobenv to jobenv.sh
$scpcmd  
echo `date` Copy command done
}

#Copy job param
function copy_over_jobparam () {
instance_id=$1
add=$2
keyfile=$3
filetocopy=$4
remotefile=`basename $filetocopy`
jobenv=`echo $filetocopy | sed 's/.json/.sh/'`
perl opt/jobParam_To_env.pl  $filetocopy > $jobenv
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  $jobenv ec2-user@$add:~/jobparam.sh"
echo Attempting copy of Job Param  $jobenv to jobparam.sh
$scpcmd 
echo `date` Copy Jobparam  done
#rm $jobenv
}




#Make resources  as inputs for pipeline
function copy_over_resources () {
instance_id=$1
add=$2
keyfile=$3
echo "Copying resources to ~/resources.tar.gz"
filetocopy=$instance_id".resources.tar"
tar -cf $filetocopy resources/*
gzip -f $filetocopy
scpcmd="scp   -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  $filetocopy.gz  ec2-user@$add:~/resources.tar.gz"
$scpcmd
ssh  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $keyfile  "ec2-user@$add" "tar -xvzf resources.tar.gz"
rm $filetocopy.gz
echo `date` Copy of Resources done
}






#Add tags for monitoring , returns nothing
function add_monitor_tags () {
	instance_id=$1
	sampleid=$2
	pipeline_name=$3
	jobid=$4
	genome=$5
	echo "Adding tags"
	aws ec2 create-tags --resources $instance_id --tags "Key=Name,Value=$jobid"
	aws ec2 create-tags --resources $instance_id --tags "Key=NGScloud,Value=shinyCPLmachine"
	aws ec2 create-tags --resources $instance_id --tags "Key=pipeline,Value=$pipeline_name"
	aws ec2 create-tags --resources $instance_id --tags "Key=sampleID,Value=$sampleid"
	aws ec2 create-tags --resources $instance_id --tags "Key=costcenter,Value=biodev"
	aws ec2 create-tags --resources $instance_id --tags "Key=refgenome,Value=$genome"
}


#Get PDFs (if any) produced by jobs
function postPDFs(){
	jobid=$1
	s3base=$2
	echo "MSG:`date` Posting back PDF files (if any)"
	pdir="$jobid.tmpdir"
	mkdir -p $pdir
	cd  $pdir
	aws s3 sync --exclude '*.log' --exclude '*.html'  --exclude '*.gz' --exclude '*.out'   --exclude '*.bai'  --exclude '*json' --exclude '*.version' --exclude '*done' --exclude '*.vcf*' --exclude postrun  --exclude '*.bam'  --exclude "*txt" s3://$s3base/jobs/$jobid .
	for file in `find . -name "*pdf"`; do
		base=`basename $file` 
		nf=$jobid".$base"
		cp $file $nf
		echo "MSG:Posting $nf"
		Rscript --vanilla  ../slackpostfiles.R  $nf
	done
	cd ..
	rm -fr $pdir
}

