

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. `dirname $DIR`/resources/bucket.sh

aws s3 ls --recursive --summarize $OUTBUCKET |grep "Total Objects" |cut -f 2 -d: |perl -pe 's/\s+//'
