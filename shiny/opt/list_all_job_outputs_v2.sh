#!/bin/sh


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. `dirname $DIR`/resources/bucket.sh

perl  -e 'print "Date\ttime\tsizemb\tjobid\tfilebasename\tsizestring\tfullpath\tfiletype\tsubpath\n"'
aws s3 ls   --recursive $OUTBUCKET  |perl -MFile::Basename -lane 'BEGIN{@suffixlist=("vcf","log","vcf.gz","bai",".bw",".bigwig",".bg",".gz",".out",".bedgraph","json","tracking","done","anno",".bam",".tbi",".txt",".tsv",".csv",".pdf",".ps",".md",".Rmd",".html");};
	$o=$F[-1];s/\s+/\t/;s/\s+/\t/;
	s/ /\t/;
	s/\s+jobs\//\t/;
	s/\//\t/;
@F=split;my $bytes=$F[2];$F[2]=$bytes/1e06; $sizekb=$bytes/1e03;push(@F,$sizekb);$F[0]="$F[0] $F[1]"; push(@F,$o);  ($name,$path,$suffix) = fileparse($o,@suffixlist); print join"\t",(@F,$suffix,$path) if /job|workfl/;$bytes=0' 

