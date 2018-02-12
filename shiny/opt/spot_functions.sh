
# Cloud functions for spot instances
#Spot instance methods for EC2

#returns the request id
#Makes the request based on instance type, AZone and spot price
#returns the sir-XXXXXXX requets ID
function request_spot_instance (){
	if [ $# -lt 3 ];then
	#	echo "Usage: request_spot_instance instancetype price zone"
	#	echo "Bids:c3.large:0.05,c3.xlarge:0.105,c3.2xlarge:0.21,c3.4xlarge:0.42,c3.8xlarge:0.84,m3.2xlarge:0.26,m3.large:0.066"
	#	return 1
		exit 1
	fi
	#echo "#$instance_type bidding:\$$bid_price zone=$zone"
	
	instance_type=${1:-"m3.large"}
	bid_price=${2:-0.067}
	zone=${3:-"us-east-1b"}
	volsize=${4:-"12"}

	templatefile="templates/spot_config_template.json"

	if [ ! -e $templatefile ];then
		echo "Error: No template given"
		exit
	fi

	mkdir -p req
	json=`perl -e 'print int(rand(333443)).time()'`".spotreq.json"
	perl -e '$file=shift;$inst=shift;$zone=shift;$volsize=shift;open(IN,$file);while(<IN>) { s/INSERTVOLSIZE/$volsize/;s/INSERTINSTANCETYPE/$inst/;s/INSERTZONE/$zone/; print  };close IN;' $templatefile $instance_type $zone $volsize > req/$json
	aws ec2 request-spot-instances  --spot-price $bid_price --instance-count 1 --type "one-time"  --launch-specification file://req/$json| jq .SpotInstanceRequests[].SpotInstanceRequestId |perl -pe 's/\"//g'
	

}

#Return the i-XXXX instance id
function get_spot_instanceid  (){
	requestid=$1
	instance_id=`aws ec2 describe-spot-instance-requests --spot-instance-request-ids $requestid | jq .SpotInstanceRequests[].InstanceId |perl -pe 's/\"//g' `
	echo $instance_id
}

#Get status code, should only proceed once it has been fulfilled
function get_spot_status  (){
	#fulfilled
	requestid=$1
	code=`aws ec2 describe-spot-instance-requests --spot-instance-request-ids $requestid| jq .SpotInstanceRequests[].Status.Code |perl -pe 's/\"//g' `
	echo $code
}


#Wait for spot to be ready
function wait_for_spot  (){
        requestid=$1
until  aws ec2 describe-spot-instance-requests --spot-instance-request-ids $requestid| jq .SpotInstanceRequests[].Status.Code  | grep fulfilled
do
    msg=`aws ec2 describe-spot-instance-requests --spot-instance-request-ids $requestid |jq .SpotInstanceRequests[].Status.Message`
    echo "MSG:`date` request $requestid not ready:$msg"
    #Terminate while waiting if the request is too low
    if aws ec2 describe-spot-instance-requests --spot-instance-request-ids $requestid |jq .SpotInstanceRequests[].Status.Message |grep -q "is lower than the minimum required";then
	echo "This request $request id is being terminated because bid price was too low"
	aws ec2 cancel-spot-instance-requests --spot-instance-request-ids $requestid
    fi
  sleep 20
done
sleep 10
retcode=$(get_spot_status $requestid)
echo "MSG:`date` The requested $requestid code=$retcode is ready"
}


function mainprocess (){
	echo 1
	
	#get the best bid price for the instance type
	
	#Request the spot instance

	# Wait for it to be fulfilled

	# Now fulfilled, get the instance id

	# Wait for the instance to be ready
	
}
