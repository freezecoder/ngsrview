# ngsrview
Simple file format viewer for NGS variant data

Description
================

Use this package to take a quick peak/inspection at the following types of files

1. Gemini TSV output files
2. snpEff TSV output files
3. AnnoVCF TSV output files


Installation
===============

```{r}
library(devtools)
install_github("freezecoder/ngsrview")
```

Usage
==================

```{r}
library(shiny)
library(DT)
library(shinyjs)
library(data.table)
library(googleVis)
library(ggplot2)
library(rjson)

genericNGSTestApp()
```

Open a browser to the port the shiny app is running, then upload some files.

Download  [this](inst/extdata/sample_vtable.tsv) input file and use it as an input to the viewer.


