#!/bin/sh

perl -e 'print "user\tpid\tcommand\n"'
ps aux |grep -v ^root |perl -lane 'next if $.==1; @F=split();printf "$F[0]\t$F[1]\t%s\n",join" ",@F[3 .. $#F]' 
