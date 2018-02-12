#!/bin/sh

file=$1

tabix -f -p vcf $file
bash opt/VCF_printAllTags.sh $1 2> /dev/null| perl opt/effParser.pl 
