library(shiny)
library(RCurl)
library(leaflet)
library(tidyverse)
library(sf)
library(shinyjs)

#github repository
#gitrepo <- "jagingrich/samo_website"

#USER INTERFACE CODE
ui <- fluidPage(
  #position of loading progress bar
  tags$head(tags$style(".shiny-notification {position: fixed; top: 45%; left: 40%; width: 20%")),
  #dimensions of the app window
  tags$head(tags$script('
          var dimension = [0, 0];
	        $(document).on("shiny:connected", function(e) {
		              dimension[0] = window.innerWidth;
		              dimension[1] = window.innerHeight;
		              Shiny.onInputChange("dimension", dimension);
	        });
	        $(window).resize(function(e) {
		              dimension[0] = window.innerWidth;
		              dimension[1] = window.innerHeight;
		              Shiny.onInputChange("dimension", dimension);
	        });
  ')),
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
                         conditionalPanel('output.state', 
                                          selectInput("features", label = NULL, choices = "", selected = "", width = "100%"))
           )
    ),
    # Description panel
    column (5,
            style = "height: 100vh; overflow-y: auto;",
            div(id = "top", " "),
            span(htmlOutput("title"), style = "font-size:30px;" ),
            span(htmlOutput("header"), style = "font-size:14px;" ),
            span(htmlOutput("body", width = "auto", height = "auto")),
            span(htmlOutput("footer"), style = "font-size:14px;" ),
            span(htmlOutput("date"), style = "font-size:10px;" )
    )
  )
)

#WEBSITE SERVER CODE
server <- function(input, output, session) {
  #saving values for loading and updating the map
  v <- reactiveValues(gitrepo = "jagingrich/samo_website", #update github repository here
                      width = NULL,
                      state = 0,
                      desc = NULL,
                      actual = NULL,
                      restored = NULL,
                      names = NULL,
                      crosstab = NULL,
                      pal = NULL,
                      factPal = NULL,
                      pn = NULL) 
  
  output$state <- reactive({
    v$state==1
  })
  outputOptions(output, "state", suspendWhenHidden = FALSE)
  
  #loading data on app start
  observe({
    if (v$state == 0) {
      
      #reading in all descriptions
      allDesc <- list()
      withProgress(message = "Loading: ", value = 0, {
        n <- 30
        
        #reading monuments .gpkg file
        load_layer <- function(path, lyrs, key, abbrev) {
          layer <- read_sf(path, layer = lyrs$name[grep(key, lyrs$name)]) %>%
            mutate(ID = paste0(ID, abbrev)) %>%
            st_transform('+proj=longlat +datum=WGS84') %>% 
            mutate(Name = paste0("(", Label, ") ", Name))
          st_geometry(layer) <- "geometry"
          return(layer)
        }
        
        #Loading GIS monument layers
        gpkg_path <- paste0("https://raw.githubusercontent.com/", v$gitrepo, "/main/Data/mapFeatures/AES_Monuments_20230207.gpkg")
        incProgress(0, detail = "Map Layers")
        layers <- st_layers(gpkg_path)
        incProgress(1/n, detail = "Actual State Plan")
        actual <- load_layer(gpkg_path, layers, "Actual", "A")
        incProgress(1/n, detail = "Restored State Plan")
        restored <- load_layer(gpkg_path, layers, "Restored", "R")
        v$actual <- actual
        v$restored <- restored
        
        #cleaning and sorting monument names
        clean_names <- function(gitrepo, actual, restored) {
          mt_names <- rbind(actual, restored) %>%
            filter(!grepl("X", ID)) %>%
            separate(ID, 
                     into = c("num", "text"), 
                     sep = "(?<=[0-9])(?=[A-Za-z])",
                     fill = "right") 
          mt_labels <- unique(mt_names %>%
                                mutate(text = ifelse(is.na(mt_names$text), "a", text)) %>%
                                arrange(text) %>%
                                arrange(as.numeric(num)) %>%
                                pull(Label))
          mt_names <- unique(mt_names %>%
                               mutate(text = ifelse(is.na(mt_names$text), "a", text)) %>%
                               arrange(text) %>%
                               arrange(as.numeric(num)) %>%
                               pull(Name))
          mt_names <- data.frame("Labels" = c("0", mt_labels), "Monument" = c("", mt_names))
          mt_names$order <- c(1:nrow(mt_names))
          
          mt_files <- data.frame(
            "name" = c("(0)Introduction", "(1-3)UnidentifiedLateHellenisticBuildings", "(4)BuildingA", "(5)ByzantineFortification", "(6)Milesian", "(7)DiningRooms", "(8-10)NicheCultRooms", 
                       "(11a)Stoa", "(11b)MonumentsStoaTerrace", "(12)Nike", "(13)Theater", "(14)AltarCourt", "(15)Hieron", "(16)HallofVotiveGifts", "(17)HallofChoralDancers", "(18)SacredWay", 
                       "(20)RotundaofArsinoeII", "(22)Sacristy", "(23)Anaktoron", "(24)DedicationofPhilipandAlexander", "(25)TheatralCircle", "(26)PropylonofPtolemyII", "(28)DoricRotunda", 
                       "(29)Neorion", "(30)MonumentPlatformsSteppedRetainingWall", "(31)IonicPorch"
            ))
          mt_files$Labels <- unlist(lapply(strsplit(mt_files$name, "\\(|\\)"), `[[`, 2))
          mt_files$path <- paste0("Data/mapDescriptions/", mt_files$name)
          mt_files$download_url <- paste0("https://raw.githubusercontent.com/", gitrepo, "/main/", mt_files$path)
          
          #file - monument linking table
          out <- merge(mt_names, mt_files, by = "Labels", all=T) %>%
            arrange(order)
          out
        }
        
        #table of names
        crosstab <- clean_names(v$gitrepo, actual, restored)
        v$names <- crosstab %>%
          filter(name != "(0)Introduction") %>%
          pull(Monument)
        v$crosstab <- crosstab
        
        #reading elements from description .txt files and pulling images
        read_desc <- function(crosstab, keys = NULL) {
          sub <- crosstab %>%
            filter(name == keys)
          download_url <- paste0(sub$download_url, "/SamoWebsite_", sub$name)
          txt <- trimws(readLines(paste0(download_url, ".txt")))
          txt <- txt[txt!=""]
          txt <- txt[txt!="\t"]
          
          #generating name
          if (sum(grepl("Monument:|Title:", txt, ignore.case = T)) != 0) {
            name_index <- grep("Monument:|Title:", txt, ignore.case = T)
            name <- txt[grep("Monument:|Title:", txt, ignore.case = T)]
            name <- gsub("Monument: |Title: ", "", name)
            name <- paste0("<b>", name, "</b>")
          } else {
            name_index <- 0
            name <- NA
          }
          
          #generating header
          if (sum(grepl("Part:|Date:|Material:|Location:", txt, ignore.case = T)) != 0) {
            header_index <- grep("Part:|Date:|Material:|Location:", txt, ignore.case = T)
            header <- txt[grep("Part:|Date:|Material:|Location:", txt)]
            header <- ifelse(grepl("Part:", header), paste0("<b>", header, "</b>"), header)
            header <- gsub("Part: ", "</br>", header)
            header <- gsub("Date: |Material: |Location: ", "", header)
            header <- paste(c(header), sep='</br>', collapse ='</br>')
          } else {
            header_index <- name_index
            header <- NA
          }
          
          #generating bibliography
          if (sum(grepl("bibliography", txt, ignore.case = T)) != 0) {
            footer_index <- grep("bibliography", txt, ignore.case = T):length(txt)
            footer <- txt[(min(footer_index) + 1):length(txt)]
            footer <- footer[grep("Document updated:|JAG_UNEDITED", footer, invert = T, ignore.case = T)]
            footer <- paste(c("<b>Selected Bibliography</b>", footer), sep='</br>', collapse ='</br>')
          } else {
            footer_index <- length(txt) + 1
            footer <- NA
          }
          
          #generating body
          body <- txt[-c(name_index, header_index, footer_index)]
          body_index <- ifelse(grepl("caption:", body, ignore.case = T), "caption", "body")
          body <- gsub("Caption: ", "", body)
          
          #reading images
          img_out <- vector()
          if (sum(body_index == "caption") != 0) {
            img_out <- paste0(download_url, "_Image", 1:sum(body_index == "caption"), ".jpg")
          }
          
          #output
          desc_out <- list("name" = name, "header" = header, "body_index" = body_index, "body" = body, "footer" = footer, "images" = img_out)
          return(desc_out)
        }
        
        #loading monument descriptions
        for (i in crosstab$name) {
          mt <- crosstab %>%
            filter(name == i) %>%
            pull(Monument)
          mt[mt == ""] <- "(0) Introduction"
          incProgress(1/n, detail = mt)
          allDesc <- append(allDesc, list(read_desc(crosstab, i)))
        }
        
        incProgress(1/n, detail = "All Features Loaded")
        names(allDesc) <- crosstab$name
        v$desc <- allDesc
        
        #Color palette for phases
        pal <- c("1" = "#94d1e7",
                 "2" = "#007abc",
                 "3" = "#00a33c",
                 "4" = "#ff871f",
                 "5" = "#ff171F",
                 "6" = "#fdf500")
        pal <- pal[sort(unique(v$actual$Phase))]
        factPal <- colorFactor(pal, v$actual$Phase)
        pn <- st_drop_geometry(v$actual) %>% dplyr::select(Phase, Phase_Name) %>%
          distinct() %>%
          arrange(Phase) %>%
          pull(Phase_Name)
        v$pal <- pal
        v$factPal <- factPal
        v$pn <- pn
      
        incProgress(1/n, detail = "All Features Loaded")
      })
      
      #updating monument menu
      updateSelectInput(session, "features", choices = v$crosstab$Monument, selected = "")
      v$state <- 1
    }
  })
  
  #creating map
  output$map <- renderLeaflet({
    if (v$state == 1) {
    leaflet() %>%
      addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/AES_ActualStatePlan_3857/{z}/{x}/{y}.png",
               attribution = 'JAG2023 | <a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
               options = tileOptions(minZoom = 16, maxZoom = 21, tms = TRUE),
               group = "Actual Plan") %>%
      addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/AES_RestoredStatePlan_3857/{z}/{x}/{y}.png",
               attribution = 'JAG2023 | <a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
               options = tileOptions(minZoom = 16, maxZoom = 21, tms = TRUE), 
               group = "Restored Plan") %>%
      #monument shapes for the actual state plan
      addPolygons(data = v$actual %>% filter(!Name %in% v$names), 
                  color = ~v$factPal(Phase), weight = 1, opacity = 1, 
                  fillOpacity = 0.8, fillColor = ~v$factPal(Phase), 
                  layerId = v$actual %>% filter(!Name %in% v$names) %>% pull(ID), 
                  group = "Actual Plan") %>%
      addPolygons(data = v$actual %>% filter(Name %in% v$names), 
                  color = ~v$factPal(Phase), weight = 1, opacity = 0.75, 
                  fillOpacity = 0.75, fillColor = ~v$factPal(Phase), 
                  highlightOptions = highlightOptions(color = ~v$factPal(Phase), opacity = 0.95, weight=2, 
                                                      fillOpacity = 0.95, bringToFront = T), 
                  layerId = v$actual %>% filter(Name %in% v$names) %>% pull(ID), 
                  group = "Actual Plan") %>%
      #monument shapes for the restored state plan
      addPolygons(data = v$restored %>% filter(!Name %in% v$names), 
                  color = ~v$factPal(Phase), weight = 1, opacity = 1, 
                  fillOpacity = 0.8, fillColor = ~v$factPal(Phase), 
                  layerId = v$restored %>% filter(!Name %in% v$names) %>% pull(ID), 
                  group = "Restored Plan") %>%
      addPolygons(data = v$restored %>% filter(Name %in% v$names), 
                  color = ~v$factPal(Phase), weight = 1, opacity = 0.75, 
                  fillOpacity = 0.75, fillColor = ~v$factPal(Phase), 
                  highlightOptions = highlightOptions(color = ~v$factPal(Phase), opacity = 0.95, weight=2, 
                                                      fillOpacity = 0.95, bringToFront = T), 
                  layerId = v$restored %>% filter(Name %in% v$names) %>% pull(ID), 
                  group = "Restored Plan") %>%
      addLegend("bottomleft", colors = v$pal, 
                labels = v$pn, 
                opacity = 1) %>%
      addLayersControl(
        baseGroups = c("Actual Plan", "Restored Plan"),
        options = layersControlOptions(collapsed = FALSE)) %>%
      addControl(actionButton("reset", "All Monuments", style = "font-size:10px;"), 
                 position="topright", className = "leaflet-control-layers-selector")
    }
  })
  
  output$date <- renderUI({HTML("</br>---</br>Plan date: 2016-2019. Dates provided in the legend based on the interpretations by the Lehmanns.")})
  
  observeEvent(input$dimension, {
    if (v$state == 1) {
      v$width <- paste0(round(input$dimension[1] * 0.38), "px")
      proxy <- leafletProxy("map")
      if(input$features == "") { #no selection
        #zoom to all features
        fitBounds(proxy, 25.52876, 40.49953, 25.53177, 40.50177)
      }
    }
  })
  
  
  observeEvent(input$features, { #monitor which feature is selected based on selectInput
    if (v$state == 1) {
    #zooming the map
    proxy <- leafletProxy("map")
    
    if(input$features == "") { #no selection
      #zoom to all features
      fitBounds(proxy, 25.52876, 40.49953, 25.53177, 40.50177)
      
    } else { #specific feature selected
      selectA <- v$actual %>% filter(Name == input$features)
      selectR <- v$restored %>% filter(Name == input$features)
      
      #zoom to selected feature
      focus <- st_bbox(rbind(selectA, selectR)) %>% as.vector()
      fitBounds(proxy, focus[1], focus[2], focus[3], focus[4])
    }
    
    #subsetting descriptions on click
    desc <- v$desc[[v$crosstab %>%
                       filter(Monument == input$features) %>%
                       pull(name)]]
    
    if(is.na(desc$name)) {
      hide("title")
    } else {
      output$title <- renderUI({
        HTML(paste0(desc$name, "</br>"))
      })
      show("title")
    }
    
    if(is.na(desc$header)) {
      hide("header")
    } else {
      output$header <- renderUI({
        HTML(paste0(desc$header, "</br>---</br>"))
      })
      show("header")
    }
    
    output$body <- renderUI({
      tag_list <- function(number) {
        if (desc$body_index[number] == "body") {
          #body paragraph
          out <- tagList(tags$text(HTML(paste0(desc$body[number], "</br></br>")), 
                                   style = "font-size:16px;"))
        } else {
          #caption
          caps <- desc$body[desc$body_index == "caption"] 
          cap_index <- (1:length(caps))[caps == desc$body[number]]
          #image
          out <- tagList(
            tags$img(src = desc$images[cap_index],
                     width = v$width),
            tags$text(HTML(paste0("</br>", desc$body[number], "</br></br>")), 
                      style = "font-size:14px;"))
        }
        return(out)
      }
      tl <- tagList()
      for (i in 1:length(desc$body)){
        tl <- append(tl, tag_list(i))
      }
      tagList(tl)
    })
    
    if(is.na(desc$footer)) {
      hide("footer")
    } else {
      output$footer <- renderUI({
        HTML(paste0("</br>---</br>", desc$footer, "</br></br>"))
      })
      show("footer")
    }
    }
  })
  
  observeEvent(input$features, {
    #scroll to top
    runjs('
      document.getElementById("top").scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" });
    ')
  })
  
  observeEvent(input$map_shape_click, { # update the location selectInput on map clicks
    feat <- input$map_shape_click
    if(feat$group == "Actual Plan") {
      click <- unique(st_drop_geometry(v$actual) %>%
                        filter(ID %in% feat$id) %>%
                        pull(Name))
    }
    if(feat$group == "Restored Plan") {
      click <- unique(st_drop_geometry(v$restored) %>%
                        filter(ID %in% feat$id) %>%
                        pull(Name))
    }
    if(click %in% v$names) {
      updateSelectInput(session, "features", selected=click)
    }
  })
  
  #reset to all features on button click
  observeEvent(input$reset, { # reset selectInput
    updateSelectInput(session, "features", selected="")
  })
}

shinyApp(ui, server)
