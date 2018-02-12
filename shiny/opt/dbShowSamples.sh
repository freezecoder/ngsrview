#!/bin/sh
#sqlite3 main.db   "select name,smid,project from samples" |perl -pe  's/\|/\t/g'

src="/Users/loyal9/Downloads/apps/cloudgenomicslauncher"


cd $src
R -q --vanilla -e 'source("dbtables.R");dat=dblistSamples() ;write.table(dat,row.names=F,quote=F,sep="\\t");' 2> R.error |grep -v "^>"
