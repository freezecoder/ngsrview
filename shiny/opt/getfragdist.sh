#!/bin/sh

perl -lane 's/#\s+//;print if /Fragment/ .. /Mean/' $1 |perl -lane 'next if /Frag|Mean/;print'
