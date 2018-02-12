
(python opt/get_spot_duration.py --region us-east-1 --product-description 'Linux/UNIX' --bids  c3.large:0.08,c3.xlarge:0.168,c3.2xlarge:0.336,c3.4xlarge:0.672,c3.8xlarge:1.344,m3.2xlarge:0.416,m3.large:0.1056,m3.medium:0.0528,m3.xlarge:0.2128,t1.micro:0.016,m1.small:0.0352,c4.8xlarge:1.344,c4.4xlarge:0.672 |perl -lane 'print "$_\tT80"'  

python opt/get_spot_duration.py --region us-east-1 --product-description 'Linux/UNIX' --bids c3.large:0.06,c3.xlarge:0.126,c3.2xlarge:0.252,c3.4xlarge:0.504,c3.8xlarge:1.008,m3.2xlarge:0.312,m3.large:0.0792,m3.medium:0.0396,m3.xlarge:0.1596,t1.micro:0.012,m1.small:0.0264,c4.8xlarge:1.008,c4.4xlarge:0.504 | perl -lane 'print "$_\tT40"'

python opt/get_spot_duration.py --region us-east-1 --product-description 'Linux/UNIX' 	--bids c3.large:0.05,c3.xlarge:0.105,c3.2xlarge:0.21,c3.4xlarge:0.42,c3.8xlarge:0.84,m3.2xlarge:0.26,m3.large:0.066,m3.medium:0.033,m3.xlarge:0.133,t1.micro:0.01,m1.small:0.022,c4.8xlarge:0.84,c4.4xlarge:0.42 | perl -lane 'print "$_\tT50"' ) |grep -v ^Duration
