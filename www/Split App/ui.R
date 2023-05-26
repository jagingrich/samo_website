library(shiny)

# Define UI for application that draws a histogram
fluidPage(
  useShinyjs(),
  #theme
  theme = bslib::bs_theme(bootswatch = "sandstone"),
  tags$head(
    tags$style(HTML(".leaflet-container { background: #000; }"))
  ),
  # Map and description layout
  fluidRow(
    # Main panel, leaflet map
    column(7, leafletOutput("map", height="100vh"),
           absolutePanel(id = "title", class = "panel panel-default", fixed = TRUE,
                         draggable = F, top = 20, left = "auto", right = "60%", bottom = "auto",
                         width = "30%", height = "auto",
                         selectInput("features", label = NULL, choices = c("", mt_names), selected = "", width = "100%")
                         )
           ),
    # Description panel
    column (5,
      style = "height: 100vh; overflow-y: auto;",
      #selectInput("features", "Sanctuary of the Great Gods: Interactive Monuments Plan", choices = c("", mt_names), selected = "", width = "100%"),
      span(htmlOutput("title"), style = "font-size:30px;" ),
      span(htmlOutput("header"), style = "font-size:14px;" ),
      htmlOutput("body1"), imageOutput("image1", width = "auto", height = "auto"), span(htmlOutput("caption1"), style = "font-size:14px;" ),
      htmlOutput("body2"), imageOutput("image2", width = "auto", height = "auto"), span(htmlOutput("caption2"), style = "font-size:14px;" ),
      htmlOutput("body3"), imageOutput("image3", width = "auto", height = "auto"), span(htmlOutput("caption3"), style = "font-size:14px;" ),
      htmlOutput("body4"), imageOutput("image4", width = "auto", height = "auto"), span(htmlOutput("caption4"), style = "font-size:14px;" ),
      htmlOutput("body5"), imageOutput("image5", width = "auto", height = "auto"), span(htmlOutput("caption5"), style = "font-size:14px;" ),
      htmlOutput("body6"), imageOutput("image6", width = "auto", height = "auto"), span(htmlOutput("caption6"), style = "font-size:14px;" ),
      htmlOutput("body7"), imageOutput("image7", width = "auto", height = "auto"), span(htmlOutput("caption7"), style = "font-size:14px;" ),
      htmlOutput("body8"), imageOutput("image8", width = "auto", height = "auto"), span(htmlOutput("caption8"), style = "font-size:14px;" ),
      htmlOutput("body9"), imageOutput("image9", width = "auto", height = "auto"), span(htmlOutput("caption9"), style = "font-size:14px;" ),
      htmlOutput("body10"), imageOutput("image10", width = "auto", height = "auto"), span(htmlOutput("caption10"), style = "font-size:14px;" ),
      span(htmlOutput("footer"), style = "font-size:14px;" ),
      span(htmlOutput("date"), style = "font-size:10px;" )
    )
  )
)
