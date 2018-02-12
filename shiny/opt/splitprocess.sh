#!/bin/sh

if [ $# -lt 4 ];then
	echo Usage file1 file2 outdir nsplits
	exit
fi

file1=$1
file2=$2
outdir=${3:-"fqsplit"}
nsplits=${4:-4}

tlines=`gunzip -dc $file1 |wc -l | perl -lane 'print $F[0]'`
echo $file1 "$tlines is linecount"

CHUNKSIZE=`perl -e '$t=shift; $n=shift; print int($t/$n)' $tlines $nsplits`
echo Chunk size is $CHUNKSIZE over $tlines

if [ $CHUNKSIZE -lt 1 ];then
	echo Cant use a $CHUNKSIZE chunk
	exit
fi

mkdir -p $outdir
base=`basename $file1 .fastq |sed 's/R1//;s/r1//' | perl -pe 's/\.fastq.gz|\.fq.gz|_sequence.txt.gz//g'`
gunzip -dc $file1 |  split -l $CHUNKSIZE - $outdir/$base.R1.part  &
gunzip -dc $file2 |  split -l $CHUNKSIZE - $outdir/$base.R2.part &
wait

echo "Gzipping"
ls  $outdir/$base*part* |perl -lane '$o=$_; ($b,$r,$p)= ($1,$2,$3) if /(\S+)\.(R[12])\.(part[a-z]+)/; print "gzip -c $_ > $b$p.$r.fastq.gz"' | parallel -j 2

ls  $outdir/$base*part*  |grep -v "fastq.gz$" | parallel  -j 2 echo  rm {} | bash
 
#rename all part2s 


