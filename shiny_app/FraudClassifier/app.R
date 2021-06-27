#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
library(caret)
library(shiny)
library(shinyTime)
library(ggplot2)
library(DT)
library(scales)
library(dplyr)

# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("Fraudulent Transaction Detector"),
   
   # Load File
   fileInput("datafile", label = h3("Upload Transaction Data (.csv format)"), multiple = FALSE, 
             accept = c('text/csv', 'text/comma-separated-values,text/plain'), width = NULL),
   
   # Filter
   fluidRow(
     column(4,
            selectInput("filter",
                        "Filter",
                        c("All", "Fraudulent", "Not Fraudulent"))
     )
   ),
   

   # Create a new row for the table.
   DT::dataTableOutput("table")
)


# Data processing/inference helper
process_data <- function(dataframe) {
  dataframe <- subset(dataframe, select = -c(nameOrig, nameDest))
  
  dataframe <- cbind(dataframe, data.frame(hours_intraday = dataframe$step %% 24, 
                                           by_day = round(dataframe$step / 24), 
                                           day_of_week = round(dataframe$step / 24) %% 7))
  
  # Log transform  (amount, oldbalanceOrg, newbalanceOrig, oldbalanceDest, newbalanceDest)
  cont_vars <- c('amount', 'oldbalanceOrg', 'newbalanceOrig', 'oldbalanceDest', 'newbalanceDest')
  
  # add small constant to prevent inf values
  log_scaled <- sapply(data.frame(dataframe)[, cont_vars], function(x) log(x + 1))
  colnames(log_scaled) <- lapply(cont_vars, function(x) paste('log_', x, sep=''))
  
  
  dataframe <- cbind(dataframe, log_scaled)
  dataframe$type <- as.factor(dataframe$type)
  dmy <- dummyVars(" ~ type", data = dataframe, sep = '.', fullRank = TRUE)
  dataframe <- cbind(dataframe, data.frame(predict(dmy, newdata = dataframe)))
  # drop type
  dataframe <- subset(dataframe, select = -c(type))
  
  # MODEL PREDICTIONS
  # load model from RDS file
  qdaModel <- readRDS('../../rds_files/qda_model.rds')
  pred_labels <- predict(qdaModel, newdata = dataframe)
  pred_probs <- predict(qdaModel, newdata = dataframe, type = 'prob')
  dataframe <- cbind(dataframe, data.frame("Is Fraudulent" = pred_labels, "Fraud Confidence" = label_percent()(pred_probs$yes)))

  return(dataframe)
}


create_plot <- function(df) {
  
  
}



# SERVER LOGIC
server <- function(input, output) {
  
   output$table <- DT::renderDataTable(DT::datatable({
     
     inFile <- input$datafile
     if (is.null(inFile))
       return(NULL)
     
     # Get Inferences
     orig <- read.csv(inFile$datapath, header = TRUE)
     outdf <- process_data(orig)
     orig <- cbind(orig, outdf[, c("Is.Fraudulent", "Fraud.Confidence")])
     
     if (input$filter == "All") {
       data <- orig
     }
     if (input$filter == "Fraudulent") {
       data <- orig[orig$Is.Fraud == "yes",]
     }
     if (input$filter == "Not Fraudulent") {
       data <- orig[orig$Is.Fraud == "no",]
     }
     
     data
     
   }) %>% formatStyle(
     "Is.Fraudulent",
     target = 'row',
     backgroundColor = styleEqual(c("yes"), c('red')),
     color = styleEqual(c("yes"), c('white')))
   
   
   )
}

# Run the application 
shinyApp(ui = ui, server = server)

