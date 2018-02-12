#!/bin/sh

. resources/bucket.sh

perl -e 'print "Date\ttime\tsizemb\tjobid\tfile\tsizekb\n"'
aws s3 ls   --recursive $OUTBUCKET  |perl -lane '$o=$F[-1];s/\s+/\t/;s/\s+/\t/;s/ /\t/;s/\s+jobs\//\t/;s/\//\t/;@F=split;$sizekb=$F[2]/1e03;$F[2]=$F[2]/1e06; push(@F,$sizekb);print join"\t",@F if /job/' 

