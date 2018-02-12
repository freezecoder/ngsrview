       
file=$2
tz=$1

perl -e 'print "start\tcontent\tgroup\n"'
grep MSG $file  | perl -pe 's/#|#\-|\-MSG|MSG://g' |grep -v "Postrung"      \
       |	perl -lane 's/^\s//;next if /.sh/;next unless /UTC|MYT|EDT|PST/;s/Oct\s+/10-/; s/Nov\s+/11-/;s/Dec\s+/12-/;s/Jan\s+/01-/;s/Feb\s+/02-/;s/Mar\s+/03-/; s/Apr\s+/04-/; s/May\s+/05-/;s/Jun\s+/06-/;s/Jul\s+/07-/;s/Aug\s+/08-/;s/Sep\s+/09-/;  print'\
   | grep $tz 	|  perl -lane 's/^\S+\s//;@F=split();$d=shift @F;   $n=shift @F;$r=shift @F; $r=~s/UTC\s+\S+|EDT\s+\S+|PST\s+\S+//g;shift @F;print "2016-$d $n\t@F" ' \
	| perl -lane '@F=split(/\t/,$_);my($y,$m,$d,$o)=($1,$2,$3,$4) if /^(\d+)\-(\d+)\-(\d+)\s+(\S+)/; $w=$d;  if(length($d) < 2){ $w="0$d"; };print "$y-$m-$w $o\t$F[1]"' |perl -lane '$h=2;$h=1 if /install/i; $h=3 if /Load/i;print "$_\t$h";$h=0;'
