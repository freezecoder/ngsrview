#!/bin/sh

. resources/bucket.sh

perl -e 'print "Date\tsizestring\tjobid\tsubpath\tfilebasename\tfullpath\tfiletype\n"'
aws s3 ls --human-readable  --recursive $OUTBUCKET  |perl -lane '$o=$F[-1];s/\s+/\t/;s/\s+/\t/;s/ /\t/;s/\s+jobs\//\t/;s/\//\t/;$suff=`basename $F[4]`;chomp $suff; $suff=~s/.gz|bz2|.tar//g; $suff=~s/\S+\.//; $b=`basename $o`; chomp $b; next unless /snpEff|novo|\.bed|bam|fpkm|counts|vcf/;s/\s+/ /;print "$_\t$b\t$o\t$suff"'

