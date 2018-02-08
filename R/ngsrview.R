library(shiny)
library(DT)
library(shinyjs)
library(data.table)
library(googleVis)
library(ggplot2)
library(rjson)

readGEMINI_<-function(x) {
    if (grepl("\\.gz$",x)) {
      DF <- suppressWarnings(fread(sprintf("gunzip -dc %s",x)))
    }else {
      DF <- suppressWarnings(fread(x))
    }
  if ("gene" %in% names(DF))
    setnames(DF,"gene","Gene_Name")
    if ("aa_change" %in% names(DF))
    setnames(DF,"aa_change","Amino_Acid_Change")
  
  #Set read coverage
    if ("gt_depths" %in% names(DF))
      DF$DP=as.numeric(gsub(",\\S+","",DF$gt_depths))
    if ("gt_alt_depths" %in% names(DF))
      DF$AC=as.numeric(gsub(",\\S+","",DF$gt_alt_depths))
    
    DF$Coverage=as.numeric(DF$DP)
    DF$Allele_Fraction=100*(DF$AC/DF$Coverage)
    
    
    DF$Functional_Class=DF$impact
    DF$Type=DF$impact
    DF$Transcript_BioType=DF$biotype
    DF$Effect_Impact=DF$impact_severity
    return(DF)
}

genericNGSUI<-function(id){
  ns <- NS(id)
  div(
    useShinyjs(),
    uiOutput(ns("ui"))
  )
}

genericNGSTestApp<-function(){
  options(shiny.maxRequestSize=100*1024^2) 
  choices=c("guess","csv","vtbl","html","pdf","vcf","vcf.gz","tsv")
  
    app <- shinyApp(
      ui=fluidPage(
        genericNGSUI("gt")
      ),
      server = function(input, output,session) {
    
      
        callModule(genericNGS,"gt")
      
        
      })
    runApp(app)
  
  
}

genericNGS<-function(input,output,session,dat=NULL) {
  
  output$ui<-renderUI({
    ns=session$ns
    #Page with file selector
    fluidPage(
      fluidRow(
        fileInput(ns("file"),"Input file",multiple=F) #File selector
      ),
      fluidRow(
        uiOutput(ns("fileViewPage"))   #Main UI portion
      )
    )
  })
  
  indata<-reactive({
    validate(need(input$file, message = FALSE))
    input$file
  })
  
output$test<-renderDataTable({
  getTableViewData()
})
  
  iname<-reactive({
      if (!is.null(indata())) {
        showNotification(indata()$fullpath)
        indata()$name
      }
  })
  
  infilePath<-reactive({
    if (!is.null(indata())) {
      showNotification(indata()$fullpath)
      indata()$datapath
    }
  })
  
#Return data frame from selected file
#Chooses an appropriate taoable view based on file name
getTableViewData<-reactive({
  dest=infilePath()
  fname=iname()
  #showNotification(fname)
	#View Bam file	
	if (!grepl(".bw$|\\.bedgraph|.bam$|.bai$|tbi$",fname,perl=T)) { 
		if (grepl("anno.vcf.gz$",fname)) {
			showNotification(sprintf("Generating Annotation table %s",1),duration=3)
			DF <- fread(sprintf("bash opt/annoparse.sh %s",dest),sep="\t")
			showNotification("Anno Table ready")
			
		}else if (grepl("[0-9].vcf.gz$|filt.vcf.gz|snpeff.vcf.gz",fname)) {
			showNotification(sprintf("Generating table %s",1),duration=3)
			DF <- fread(sprintf("bash opt/VCF_printAllTags.sh %s",dest),sep="\t")
			showNotification("Table is ready, displaying...")
	
		} else if (grepl("vcfchrom.txt|snpEff_genes.txt|tracking$|counts.txt$",fname)) {
			showNotification("TSV/TXT File input")
			DF <- fread(dest,header=T)
	
		} else if (grepl("novoalign_log.txt",fname) ) {
			DF <- read.csv2(pipe(sprintf("perl  opt/novoalign_result_parser.pl  %s",dest)),sep="\t")
	
		} else if (grepl(".json$",fname,perl=T) ) {
			mylist=rjson::fromJSON(file=dest)
	  		DF=as.data.frame(mylist)
	    }else if (grepl("\\.vcf$",fname)) {
	      #regular VCF
		  	DF <- fread(sprintf("bash opt/printVCF.sh %s",dest),sep="\t")	
		} else if (  grepl("\\.vtbl.tsv",fname) ) {
			  showNotification(sprintf("VCFAnno Vtable Annotation format detected in %s",dest))
		  	if (grepl(".gz",fname)) {
			  	#read gzipped file
			  	DF <- suppressWarnings(fread(sprintf("gunzip -dc %s",dest)))
			}  else {
			   DF <- suppressWarnings(fread(dest))
			}
		} else if (grepl("\\.gemini",fname)){
		    showNotification("Gemini Format detected")
		    DF=readGEMINI_(dest)
		} else {
		  showNotification("CSV input")
			DF <- fread(dest,sep="\n",header=T)	
			
		} 
		DF=as.data.table(DF)
		DF
	}
	
})


#render the table, html page or bam file
output$vfile<-DT::renderDataTable({
	DF=getTableViewData()
	
	if (!is.null(input$vselectedgene))
		DF=subset(DF, Gene_Name %in% input$vselectedgene  )
	
	if (!is.null(input$vcolx))
		DF=subset(DF,select=input$vcolx)
	
	
	datatable(DF,escape=FALSE,filter='top',rownames=FALSE,
	extensions = c('ColReorder','Buttons'),
		options = list(
		colReorder = list(realtime = FALSE),
		pageLength = 30,
	    dom = 'Bfrtip',
		asStripeClasses  = list(),
	     buttons = c('excel', 'csv' ,'copy', 'pdf','colvis')
		)) 
	
	
})

#Download the vtable
output$vtbldown <- downloadHandler(
   filename = function() {
     paste('variantTable', Sys.Date(), '.csv', sep='')
   },
   content = function(con) {
   	DF=getTableViewData()
	if (!is.null(input$vselectedgene))
   		DF=subset(DF, Gene_Name %in% input$vselectedgene  )
	if (!is.null(input$vcolx))
   		DF=subset(DF,select=input$vcolx)
    write.csv(DF, con)
   }
)


#Single File viewer page, most types supported
output$fileViewPage<-renderUI({
  ns=session$ns
	session$sendCustomMessage(type = "vresetValue", message = "vselectedgene")
  dest=infilePath()
  fname=iname()
	#BAM Files, dont do anything
	if (grepl(".bam$|.bai$|tbi$|\\.bw$|bedgraph$|bedgraph.gz$",fname,perl=T)) { 
		# BAM or No View because I dont know the file type
		fluidPage(
	  	h3(sprintf("BigWig/BAM/Tabix Viewer %s. See the IGV/Genome Browser Section",1,fname))
		)
		
	}else if (grepl("pdf$|.html$",fname,perl=T)) {
		#HTML & PDF files View
		myiframe <- tags$iframe(src=dest, height=800, width=1200)
		fluidPage(
			h3(sprintf("Viewer: %s",fname)),
			myiframe
		)
	}else if (grepl("\\.vtbl.tsv|\\.anno.vcf|\\.gemini",fname,perl=T)) {
		#VTABLE VCF or generic table viewer. For Gemini or hg19 annotations only from anno.vcf.gz files or vcf.gz
		dat=getTableViewData()
		cx=as.character(names(dat))
		div(
		fluidPage(
			h2("Variants View"),
			#attach js and css assets from web
			singleton(tags$head(tags$link(href='https://cdnjs.cloudflare.com/ajax/libs/admin-lte/2.4.2/css/AdminLTE.min.css',rel='stylesheet',type='text/css'))),
			singleton(tags$head(tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/notify/0.4.2/notify.min.js"))),
			tags$head(tags$style(HTML("#vfile tbody {  padding: 1px 2px 1px 2px; font-family: Arial; font-weight:normal; font-size:x-small}"))),
			actionButton("vreset","Reset Gene Filters",class="btn-black btn-sm"),	
			tabsetPanel(type="pills",
			#Generic Table View
			tabPanel("Table",
					h3(sprintf("Table Viewer: %s",fname)),
						wellPanel(
							selectInput(ns("vcolx"),"Columns",cx,selected=head(cx,15),multiple=T)
				),
				downloadButton(ns("vtbldown"),icon("file-excel-o"),class="btn-sm btn-black"),
				DT::dataTableOutput(ns("vfile"))	
			),
			# Analytics Panels view
			tabPanel("Analytics Report",
		    tags$script("
		       Shiny.addCustomMessageHandler('vresetValue', function(variableName) {
		         Shiny.onInputChange(variableName, null);
		       });
		     "),	
			fluidRow(
				uiOutput(ns("vtblannoviewer"))
			)
			)

		)
		),style="overflow-x:scroll;"
		)
	}else {
		showNotification("Displaying generic table view")
		dat=getTableViewData()
		cx=as.character(names(dat))
		div(
		fluidPage(
			h2("Generic Table Viewer"),
			singleton(tags$head(tags$link(href='https://cdnjs.cloudflare.com/ajax/libs/admin-lte/2.4.2/css/AdminLTE.min.css',rel='stylesheet',type='text/css'))),
		    tags$head(tags$style(HTML("#vfile tbody {  padding: 1px 2px 1px 2px; font-family: Arial; font-weight:normal; font-size:x-small}"))),
			tabsetPanel(type="pills",
			tabPanel("Table",
					h3(sprintf("Table Viewer: %s",fname)),
						wellPanel(
							selectInput(ns("vcolx"),"Columns",cx,selected=head(cx,15),multiple=T)
				),
				downloadButton(ns("vtbldown"),icon("file-excel-o"),class="btn-sm btn-black"),
				DT::dataTableOutput(ns("vfile"))	
			)
			)
		),style="overflow-x:scroll;"
	)
		
	}
	
	
})
#Hides/toggles table in igv view
shinyjs::onclick("hidevsel",shinyjs::toggle(id = "igvvarselector", anim = FALSE))
shinyjs::onclick("closevsel",shinyjs::toggle(id = "igvvarselector", anim = FALSE))


#Variant table UI
#Main UI with panels
output$vtblannoviewer<-renderUI({
  ns=session$ns
  dest=iname()
  dat=getTableViewData()
  dat$Coverage=as.numeric(dat$DP)
  dat$AC=as.numeric(dat$AC)
  dat$Allele_Fraction=100*(dat$AC/dat$Coverage)
  nms=as.character(names(dat))
  #Get numeric vs character columnsin data.table
  numerics=names(dat[, .SD, .SDcols = sapply(dat, is.numeric)])
  aafs=grep("aaf|ac|Alle",names(dat),value=T) #include some others
  numerics=c(numerics,aafs)
  charnms=names(dat[, .SD, .SDcols = sapply(dat, is.character)])
  charnms=grep("aaf|ac",charnms,value=T,invert=T)
  
  if (  grepl("\\.vtbl.tsv$|\\.vtbl.tsv.gz$|anno.vcf.gz$|\\.gemini",dest) ) {
    fluidPage(
      selectInput(ns("vselectedgene"),label="Choose Gene",multiple=T,selected=NULL,choices=unique(dat$Gene_Name)),
      tags$head(tags$style(HTML("#vtgenefreqtable tbody {   font-weight:normal; font-size:x-small;  }"))),
      tags$head(tags$style(HTML("#vtgeneclasstable tbody {  padding: 1px 2px 1px 2px; font-family: tahoma; font-weight:normal; font-size:x-small}"))),
      div(id="vtblview",
          fluidRow(
            column(4,
                   div(class="box box-info",
                       "Gene Frequency",
                       p("Click gene to update charts"),
                       downloadButton(ns("vtgenedownload"),icon("file-excel-o"),class="btn-sm btn-black"),
                       div(DT::dataTableOutput(ns("vtgenefreqtable")),style="overflow-x:scroll; overflow-y:scroll;")
                   )
            ),
            column(4,
                   div(class="box box-info",
                       "Variant Class",
                       htmlOutput(ns("vteffpie"))
                   )
            ),
            column(4,
                   div(class="box box-info",
                       "Histogram",
                       plotOutput(ns("vthistoplot"))
                   )
            )	
          ),
          fluidRow(
            column(4,
                   div(class="box box-info",
                       "Gene Impact",
                       selectInput(ns("vimpactvar"),"Select",c("Gene_Name","Amino_Acid_Change","rs_ids"),selected="rs_ids"),
                       checkboxInput(ns("vtflip"),"Flip",value=NULL),
                       DT::dataTableOutput(ns("vtgeneclasstable"))
                       ,style=" overflow-x:scroll;overflow-y:scroll;")
            ),
            column(4,
                   div(class="box box-info",
                       "Scatter Variables",
                       fluidRow(
                         column(4,selectInput(ns("vxvar"),"X axis",numerics,multiple=F,selected="Coverage")),
                         column(4,selectInput(ns("vyvar"),"Y axis",numerics,multiple=F)),
                         column(4,selectInput(ns("vycvar"),"Color Variable",charnms,multiple=F,selected="Type"))
                       ),
                       plotOutput(ns("vtscatterplot"))
                   )
            ),
            column(4,
                   div(class="box box-info",
                       "Database Population Frequencies",
                       plotOutput(ns("vfractionplot"))
                   )
            )	
          )		
      )
    )
  }
})



#Vtable variant mini viewer
#Plots variant analytics responsive by gene

# panels 
#Custom css for these tables
vtableCSS<-function(){
vtcss="
    padding: 1px 2px 1px 2px;
    font-family: tahoma;
    font-weight: normal;
    position: relative;
       clear: both;
     *zoom: 1;
     zoom: 1;
     border-top: 1px solid #ddd;
     font-size: x-small;
"
return(vtcss)
}



#reset to all genes
observeEvent(input$vreset, {
	showNotification("Resetting to all genes")
	session$sendCustomMessage(type = "vresetValue", message = "vselectedgene")
 })

#fucntion to make gene summary table
vtGeneSummaryTable<-function(DF){
	DF$AC=as.numeric(DF$AC)
	DF$Coverage=as.numeric(DF$DP)
	x=DF[,by="Gene_Name",list(
		Variants=length(unique(Amino_Acid_Change)),
		High_Impact=length(grep("HIGH",Effect_Impact,value=T)),
		Clinvar_Drug_Or_Pathogenic=length(grep("drug|patho",clinvar_sig,value=T)),
		Known_Somatic_In_Cosmic=length(grep("COSM",cosmic_ids,value=T)),
		Frame_Affecting_Indels=length(grep("frameshift|disruptive|frame_shift",Type,ignore.case=T,value=T)),
		Silent_SNVs=length(grep("nonsyn|non_syn|silent",Type,value=T,ignore.case=T)),
		Average_Depth=round(mean(Coverage),digits=2),
		Avg_AlleleFraction=round(mean(100*AC/Coverage),digits=2),
		Amino_Acid_Changes=paste(head(unique(Amino_Acid_Change),12),collapse=",")
		)][order(-Clinvar_Drug_Or_Pathogenic)]
	return(x)
}

#Download the gene summary file
output$vtgenedownload <- downloadHandler(
   filename = function() {
     paste('genetable', Sys.Date(), '.csv', sep='')
   },
   content = function(con) {
   	DF=getTableViewData()
   	DF=subset(DF,grepl("\\S",Amino_Acid_Change,perl=T))
   	sdf=vtGeneSummaryTable(DF)
     write.csv(sdf, con)
   }
)



#Return filtered dataset
filtgetTableViewData<-reactive({
	mydata<-getTableViewData()
	mydata$AC=as.numeric(mydata$AC)
	
	mydata$Coverage=as.numeric(mydata$DP)
	mydata=subset(mydata, Coverage >=2)
	mydata$Allele_Fraction=100*(mydata$AC/mydata$Coverage)
	
	arbgene=head(unique(mydata$Gene_Name),1)
	if (!is.null(input$vselectedgene)) 
		mydata=subset(mydata, Gene_Name %in% input$vselectedgene  )
	
	
	return(mydata)
})

#First gene clickable table view - uses and displays unfiltered data
output$vtgenefreqtable<-DT::renderDataTable({
	DF=getTableViewData()
	DF=subset(DF,grepl("\\S",Amino_Acid_Change,perl=T))
	sdf=vtGeneSummaryTable(DF)
	#correlation analysis,but need a group variable
	#saveRDS(sdf,"genestat.rds")
	#ggpairs(subset(dat,select=-Gene_Name))
	mm=names(sdf)
	mm=gsub("_"," ",mm)
	setnames(sdf,mm)
	geneclickjs=JS(
	        "table.on('click.dt', 'tr', function() {
	                           $(this).toggleClass('selected');
	   						var data=table.row(this).data();
							Shiny.onInputChange('tvselectedgene',data[0]);
							//$.notify( data[0] + ' selected', 'success');
			});"
		)
	datatable(sdf,filter="top",rownames=FALSE,selection="single",callback=geneclickjs,options=list(pageLength=6)) %>% 
	formatStyle(names(sdf), `font-size` = '12px', fontWeight='normal')
})

output$vtgeneclasstable<-DT::renderDataTable({
	DF=filtgetTableViewData()
	if (input$vtflip){
		formu=as.formula(sprintf("Type ~ %s",input$vimpactvar))
	}else {
		formu=as.formula(sprintf("%s ~ Type",input$vimpactvar))
	}

	sdf=dcast.data.table(DF,formu,value.var="Allele_Fraction",fun.aggregate=length)
	datatable(sdf,filter="top",rownames=FALSE,selection="none",options=list(pageLength=6)) %>% 
	formatStyle(names(sdf), `font-size` = '12px', fontWeight='normal')
})


#Pie charts
output$vteffpie<- renderGvis({
	DF=filtgetTableViewData()
	
	sg=""
	if (!is.null(input$vselectedgene))
		sg=input$vselectedgene
	
	dat=DF[,by="Functional_Class",list(
		Count=length(Gene_Name)
		)]
	c1=gvisPieChart(dat, labelvar="Functional_Class",numvar="Count",
                    options=list(
                    slices="{4: {offset: 0.2}, 0: {offset: 0.3}}",
                    title=sprintf("%s Variant Class",sg),
                    pieSliceText='label',
                    pieHole=0.5))
		#Transcript_BioType
	dat=DF[,by="Transcript_BioType",list(
			Count=length(Gene_Name)
			)]
	
	#Variant Type
	dat=DF[,by="Type",list(
							Count=length(Gene_Name)
							)]
	c3=gvisPieChart(dat, labelvar="Type",numvar="Count",
				                    options=list(
				                    slices="{4: {offset: 0.2}, 0: {offset: 0.3}}",
				                    title=sprintf("%s Variant Type",sg),
				                    pieSliceText='label',
				                    pieHole=0.5))
	gvisMerge(c3,c1)			
})

#histogram plot
output$vthistoplot<-renderPlot({
	var="Coverage"	
	sg=""
	if (!is.null(input$vselectedgene))
		sg=input$vselectedgene
	DF=filtgetTableViewData()
	MAXPOINTS=1000
	if (length(DF$Type) >MAXPOINTS)
		DF=head(DF,MAXPOINTS)
	

	qplot(DF[[var]],
	      geom="histogram",
	      binwidth = 0.5,  
	      main = sprintf("%s Histogram for %s",sg,var), 
	      xlab = var, 
	      fill=I("blue"), 
	      col=I("blue")) + theme_bw()
})

#Scatter plot of variables
output$vtscatterplot<-renderPlot({
	MAXPOINTS=300
	DF=filtgetTableViewData()
	xvar=input$vxvar
	yvar=input$vyvar
	cvar=input$vycvar
	
	#Set defaults
	#xvar="Coverage"
	#yvar="Allele_Fraction"
	#cvar="Type"
		
	DF[[xvar]]=as.numeric(DF[[xvar]])
	DF[[yvar]]=as.numeric(DF[[yvar]])
	
	if (length(DF$Type) >MAXPOINTS)
		DF=head(DF,MAXPOINTS)
	
	#	saveRDS(DF,"tmp.rds")
	ggplot(DF, aes_string(x=xvar, y=yvar, color=cvar)) + geom_point() + theme_bw()
	
})

#Plot of Database pop. frequencies
#Only show this plot if we have a gene selected, otherwise it's not useful
output$vfractionplot<-renderPlot({
	nd = filtgetTableViewData()
#	showNotification("Pop plot")
#	showNotification(nrow(nd))
	sg="ABC"
	if (!is.null(input$vselectedgene)) {
  	sg=input$vselectedgene

	MAXPOINTS=500
	if (length(nd$Gene_Name) >MAXPOINTS)
		nd=head(nd,MAXPOINTS)
	
	nms=grep("Gene_Name|Amino_Acid_Change|aaf",names(nd),value=T)
	nd=subset(nd,select=nms)
	nd <- melt(nd,id.vars=c("Gene_Name","Amino_Acid_Change"))
	nd=subset(nd,value !=".")
	#	nd$group=nd$variable
	#nd=subset(nd,grepl("Rate",variable))
	#nd$variable=gsub("aaf_|_float","",nd$variable)
	print(dim(nd))	
	p=ggplot(nd,aes(variable,value,fill=Amino_Acid_Change)) + geom_bar(stat = "identity") 
	p=p+ theme_bw() + theme(axis.text.x = element_text(size=16,angle=90)) 
	p=p+ggtitle(sprintf("%s ",sg))
	p
	}
})


#This is a short variant table displayed above the genome browser for quick linking to diff genome positions
output$vtuniqvariants<-DT::renderDataTable({
	dat=getTableViewData()
	dat=as.data.table(dat)
	dat$Type=as.factor(dat$Type)
	dat$Coding_Change=as.factor(dat$Codon_Change)
	dat$Amino_Acid_Change=as.factor(dat$Amino_Acid_Change)
	dat$Gene_Name=as.factor(dat$Gene_Name)
	dat$coord=paste0(dat$CHR,":",dat$POS,"-",dat$POS+10)
	dpcols=grep("DP",names(dat),value=T,ignore.case=F)
	cols=c("coord","Gene_Name","Amino_Acid_Change","Codon_Change","Type","CHROM","REF","ALT")
	dat=subset(dat,select=c(cols,dpcols))
	dat=unique(dat)
	vclickjs=JS(
	        "table.on('click.dt', 'tr', function() {
	                        $(this).toggleClass('selected');
	   						var data=table.row(this).data();
							var toshow= data[1] + ':' + data[2];
							Shiny.onInputChange('vtcoord',toshow); // set the variant infocus to show
							$.notify( data[1] + ' ' + data[2]  +  ' selected', 'warning');
							$('#vtoreplace').html('<h2><span class=\"label label-danger\">' + toshow + '</span></h2>');
							$('#otoreplace').html('<h3><span class=\"label label-info\">' + data[4] + '</span></h3>');
							igv.browser.search(data[0]); // find it in iGV
			});"
		)
	setnames(dat,gsub("_"," ",names(dat)))
	datatable(dat,caption="Click variant to see in Genome Browser",filter="top",rownames=FALSE,selection="single",callback=vclickjs,options=list(pageLength=5)) %>%
	formatStyle(names(dat), `font-size` = '11px', fontWeight='normal')
	
})


}

#### The end
igvPanel<-function(){
  #IGV Browser View
  allbams=listbams()
  tabPanel("Genome Browser",
            fluidRow(
              column(2,
                     selectInput("showthisigvfile",div(title="Files shown in IGV","File to View"),multiple=T,selected=head(allbams,3),allbams),
                     actionButton("hidevsel","Show/Hide Variants Table"),
                     div(id="vtoreplace",h4(tags$span(class="label label-info",""))),
                     div(id="otoreplace",h4(tags$span(class="label label-info","")))		
              ),
              column(10,
                     igvjs_tags(), #required to set all req tags
                     igvjsOutput("singleigv"),		#The IGV div
                     #Hidden panel for the variants
                     absolutePanel(id = "igvvarselector", class = "panel panel-default", fixed = TRUE,
                                   draggable = TRUE, top = 60, left = "auto", right = 20, bottom = "auto",
                                   width = 800, height = "auto",
                                   wellPanel(
                                     DT::dataTableOutput("vtuniqvariants"),
                                     actionButton("closevsel","Close")
                                   ),
                                   style="overflow-x:scroll;overflow-y:scroll;opacity: 0.92;"
                     )
              )
            )
  )
  
}