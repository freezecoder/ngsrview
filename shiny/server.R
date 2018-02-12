


options(shiny.maxRequestSize=100*1024^2) 
      
shinyServer(function(input, output,session) {
        callModule(genericNGS,"gt")
})
