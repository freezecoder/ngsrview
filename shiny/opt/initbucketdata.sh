tmp=`mktemp -p . -d`

pushd $tmp

aws s3 mb s3://$id

for dir in `echo jblg jbs jobs protocols samples testing`;do
        echo Initializing $dir
        mkdir $dir
        touch $dir/init
done
aws s3 sync . s3://$id
popd
