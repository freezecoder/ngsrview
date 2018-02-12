
#export PATH=/usr/local/bin:/usr/local/sbin:~/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/loyal9/miniconda2/bin/

# https://github.com/awslabs/aws-spot-labs
#Get bidding fluctuations for spot instance requests at 50%
python opt/get_spot_duration.py --region us-east-1 --product-description 'Linux/UNIX' \
	--bids c3.large:0.05,c3.xlarge:0.105,c3.2xlarge:0.21,c3.4xlarge:0.42,c3.8xlarge:0.84,m3.2xlarge:0.26,m3.large:0.066,m3.medium:0.033,m3.xlarge:0.133,t1.micro:0.01,m1.small:0.022,c4.8xlarge:0.84,c4.4xlarge:0.42

