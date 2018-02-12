#!/bin/sh

Rscript -e 'source("loadlibs.R");source("dbtables.R");jobs=dblistJobs();saveRDS(jobs,"tjobs.rds")'
