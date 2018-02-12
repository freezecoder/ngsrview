#!/usr/bin/perl -w

use Getopt::Long;

my $skip=0;
&GetOptions(
	'skip!'=>\$skip
);

#Novoalign stderr result parser
$file=shift; 
open(IN,$file) or die "$!";
my $f=$file;
if (!$skip){
	$f=`dirname $file`;
	$f=~s/\S+\///;
}

chomp $f;
$f=~s/\.novoal.*//;
while(<IN>){
	next unless /^#/ && /:\s+\d/;
	s/#\s+//;s/\(.+//;
	chomp; 
	@F=split(":",$_);
	$F[1]=~s/^\s+//;
	$h{$F[0]}=$F[1]; 
}

$r=grep/Align/,keys %h; 




if ($r) {
printf "file\t";
foreach $k (keys %h) {
	$k=~s/\s+/_/g;
	printf "$k\t";
}

print"\n";
print join"\t",($f,values %h,"\n")

}


