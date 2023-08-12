#American Excavations Samothrace: interactive web map of the Sanctuary of the Great Gods
#Jared Gingrich, May 2023

library(shiny)
library(RCurl)
library(leaflet)
library(tidyverse)
library(sf)
library(shinyjs)

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
            span(htmlOutput("body", width = "auto", height = "auto")),
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
      withProgress(message = "Loading: ", value = 0, {
        n <- nrow(read.csv(paste0("https://raw.githubusercontent.com/", v$gitrepo, "/main/Data/mapDescriptions/SamoWebsite_mapDescriptions_Index.csv")))
        n <- n + 4
        
        #reading monuments .gpkg file
        load_layer <- function(path, lyr, abbrev) {
          layer <- read_sf(path, layer = lyr) %>%
            mutate(ID = paste0(ID, abbrev)) %>%
            st_transform('+proj=longlat +datum=WGS84') %>% 
            mutate(Name = paste0("(", Label, ") ", Name))
          st_geometry(layer) <- "geometry"
          return(layer)
        }
        
        #Loading GIS monument layers
        gpkg_path <- paste0("https://raw.githubusercontent.com/", v$gitrepo, "/main/Data/mapFeatures/SamoWebsite_Monuments.gpkg")
        #checking layers
        incProgress(0, detail = "Map Layers")
        layer <- st_layers(gpkg_path)
        #reading actual state plan
        incProgress(1/n, detail = "Actual State Plan")
        v$actual <- load_layer(gpkg_path, layer$name[grep("Actual", layer$name)], "A")
        #reading restored state plan
        incProgress(1/n, detail = "Restored State Plan")
        v$restored <- load_layer(gpkg_path, layer$name[grep("Restored", layer$name)], "R")
        
        #cleaning and sorting monument names
        clean_names <- function(gitrepo, actual, restored) {
          mt_names <- unique(rbind(restored, actual) %>%
            filter(!grepl("X", ID)) %>%
            pull(Name))
          mt_names <- data.frame("Monument" = mt_names,
                                 "Labels" = unlist(lapply(strsplit(mt_names, "\\(|\\)"), `[[`, 2))) %>%
            mutate(ID = Labels) %>%
            separate(ID, 
                     into = c("num", "text"), 
                     sep = "(?<=[0-9])(?=[A-Za-z])",
                     fill = "right")
          mt_names$num <- as.numeric(unlist(lapply(strsplit(mt_names$num, "-"), `[[`, 1)))
          mt_names <- mt_names %>%
            mutate(text = ifelse(is.na(text), "a", text)) %>%
            arrange(text) %>%
            arrange(num) %>% 
            dplyr::select(c(Labels, Monument))
          mt_names <- rbind(data.frame("Labels" = "0", "Monument" = ""), mt_names)
          mt_names$order <- c(1:nrow(mt_names))
          
          mt_files <- read.csv(paste0("https://raw.githubusercontent.com/", gitrepo, "/main/Data/mapDescriptions/SamoWebsite_mapDescriptions_Index.csv"))
          mt_files <- mt_files %>%
            mutate(path = paste0("Data/mapDescriptions/", name)) %>%
            mutate(download_url = paste0("https://raw.githubusercontent.com/", gitrepo, "/main/", path))
          
          #file - monument linking table
          out <- merge(mt_names, mt_files, by = "Labels", all=T) %>%
            arrange(order)
          out
        }
        
        #table of names
        v$crosstab <- clean_names(v$gitrepo, v$actual, v$restored)
        v$names <- v$crosstab %>%
          filter(Monument != "",
                 !is.na(name)) %>%
          pull(Monument)
        
        #reading elements from description .txt files and pulling images
        read_desc <- function(crosstab, key = NULL) {
          sub <- crosstab %>%
            filter(name == key)
          download_url <- paste0(sub$download_url, "/SamoWebsite_", sub$name)
          if (url.exists(paste0(download_url, ".txt"))) {
            txt <- trimws(readLines(paste0(download_url, ".txt"), encoding = "UTF-8"))
            txt <- txt[grep("Document updated:|JAG_UNEDITED", txt, invert = T, ignore.case = T)]
            
            #removing duplicate line breaks
            txt_index <- ifelse(txt == "", "break", "text")
            txt_rm <- vector()
            for (i in 1:length(txt_index)) {
              if (i < length(txt_index) && txt_index[i] == "break" && txt_index[i+1] == "break") {
                txt_rm <- append(txt_rm, i)
              } else if (i == 1 && txt_index[i] == "break") {
                txt_rm <- append(txt_rm, i)
              } else if (i == length(txt_index) && txt_index[i] == "break") {
                txt_rm <- append(txt_rm, i)
              }
            }
            if (length(txt_rm) != 0) {
              txt <- txt[-c(txt_rm)]
              txt_index <- txt_index[-c(txt_rm)]
            }
            
            #name
            txt_index[grep("Monument:|Title:", txt, ignore.case = T)] <- "name"
            txt[txt_index == "name"] <- gsub("Monument:|Title:", "", txt[txt_index == "name"], ignore.case = T)
            txt[txt_index == "name"] <- paste0("<b>", txt[txt_index == "name"], "</b>")
            
            #header
            txt_index[grep("Header:", txt, ignore.case = F)] <- "header"
            txt[txt_index == "header"] <- gsub("Header:", "", txt[txt_index == "header"], ignore.case = F)
            txt[txt_index == "header"] <- paste0("<b>", txt[txt_index == "header"], "</b>")
            
            #subheader
            txt_index[grep("Subheader:|Part:", txt, ignore.case = T)] <- "subheader"
            txt[txt_index == "subheader"] <- gsub("Subheader:|Part:", "", txt[txt_index == "subheader"], ignore.case = T)
            txt[txt_index == "subheader"] <- paste0("<b>", txt[txt_index == "subheader"], "</b>")
            
            #subtext
            txt_index[grep("Date:|Material:|Location:", txt, ignore.case = T)] <- "subtext"
            txt[txt_index == "subtext"] <- gsub("Date:|Material:|Location:", "", txt[txt_index == "subtext"], ignore.case = T)
            
            #caption
            txt_index[grep("Caption:", txt, ignore.case = T)] <- "caption"
            txt[txt_index == "caption"] <- gsub("Caption:", "", txt[txt_index == "caption"], ignore.case = T)
            
            #bibliography
            txt_index[grep("Bibliography", txt, ignore.case = T)] <- "bibhead"
            txt[txt_index == "bibhead"] <- "<b>Selected Bibliography</b>"
            if (sum(grepl("Bibliography", txt, ignore.case = T)) != 0) {
              txt_index[(grep("Bibliography", txt, ignore.case = T) + 1):length(txt)] <- "bibliography"
            }
            
            #body
            txt_index[txt_index == "text"] <- "body"
            txt <- trimws(txt)
            
            #reading images
            img_out <- vector()
            if (sum(txt_index == "caption") != 0) {
              img_out <- paste0(download_url, "_Image", 1:sum(txt_index == "caption"), ".jpg")
            }
            
            #output
            desc_out <- list("body" = txt, "body_index" = txt_index, "images" = img_out)
          } else {
            name <- crosstab %>%
              filter(name == i) %>%
              pull(Monument)
            name <- paste0("<b>", name, "</b>")
            #output
            desc_out <- list("body" = name, "body_index" = "name", "images" = NA)
          }
          return(desc_out)
        }
        
        #loading monument descriptions
        v$desc <- list()
        for (i in v$crosstab$name) {
          mt <- v$crosstab %>%
            filter(name == i) %>%
            pull(Monument)
          mt[mt == ""] <- "(0) Introduction"
          if (length(mt) != 0) {
            incProgress(1/n, detail = mt)
            v$desc <- append(v$desc, list(read_desc(v$crosstab, i)))
          } 
        }
        for (i in crosstab$name) {
          mt <- crosstab %>%
            filter(name == i) %>%
            pull(Monument)
          mt[mt == ""] <- "(0) Introduction"
          if (length(mt) != 0) {
            incProgress(1/n, detail = mt)
            desc <- append(desc, list(read_desc(crosstab, i)))
          } 
        }
        names(v$desc) <- v$crosstab %>%
          filter(!is.na(name)) %>%
          pull(name)
        
        #Color palette for phases
        v$pal <- c("1" = "#94d1e7",
                 "2" = "#007abc",
                 "3" = "#00a33c",
                 "4" = "#ff871f",
                 "5" = "#ff171F",
                 "6" = "#fdf500",
                 "7" = "#00000000")
        v$pal <- v$pal[sort(unique(v$actual$Phase))]
        v$factPal <- colorFactor(v$pal, v$actual$Phase, alpha = T)
        v$pn <- rbind(st_drop_geometry(v$actual), st_drop_geometry(v$restored)) %>% 
          dplyr::select(Phase, Phase_Name) %>%
          distinct() %>%
          arrange(Phase) %>%
          pull(Phase_Name)
        
        incProgress(1/n, detail = "All Features Loaded")
      })
      
      #updating monument menu
      updateSelectInput(session, "features", choices = c("", v$names), selected = "")
      v$state <- 1
    }
  })
  
  #creating map
  output$map <- renderLeaflet({
    if (v$state == 1) {
      leaflet() %>%
        addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_ActualStatePlan_3857/{z}/{x}/{y}.png",
                 attribution = 'JAG2023 | <a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
                 options = tileOptions(minZoom = 17, maxZoom = 22, tms = TRUE),
                 group = "Actual Plan") %>%
        addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/SamoWebsite_RestoredStatePlan_3857/{z}/{x}/{y}.png",
                 attribution = 'JAG2023 | <a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
                 options = tileOptions(minZoom = 17, maxZoom = 22, tms = TRUE), 
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
        addLegend("bottomleft", colors = v$pal[1:6], 
                  labels = v$pn[1:6], 
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
        mean(c(40.49953, 40.50177))
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
      
      check <- TRUE
      if (is.null(desc)) {
        check <- FALSE
        desc <- list("body_index" = NA, "body" = NA, "images" = NA)
      }
      
      if (!check | sum(is.na(desc$body)) == length(desc$body)) {
        output$body <- NULL
      } else {
        output$body <- renderUI({
          tag_list <- function(number) {
            if (desc$body_index[number] == "name") {
              #monument name/title
              out <- tagList(tags$text(HTML(paste0(desc$body[number], "</br>")), 
                                       style = "font-size:30px;"))
            } else if (desc$body_index[number] == "header") {
              #header
              out <- tagList(tags$text(HTML(paste0(desc$body[number], "</br>")), 
                                       style = "font-size:24px;"))
            } else if (desc$body_index[number] %in% c("subheader", "bibhead", "body")) {
              #subheader, bibliography, body
              out <- tagList(tags$text(HTML(paste0(desc$body[number], "</br>")), 
                                       style = "font-size:16px;"))
            } else if (desc$body_index[number] %in% c("subtext", "bibliography")) {
              #date, location, material
              out <- tagList(tags$text(HTML(paste0(desc$body[number], "</br>")), 
                                       style = "font-size:14px;"))
            } else if (desc$body_index[number] == "caption") {
              #caption
              caps <- desc$body[desc$body_index == "caption"] 
              cap_index <- (1:length(caps))[caps == desc$body[number]]
              #image
              if (desc$body[number] != "") {
                out <- tagList(
                  tags$img(src = desc$images[cap_index],
                           width = v$width),
                  tags$text(HTML(paste0("</br>", desc$body[number], "</br>")), 
                            style = "font-size:14px;"))
              } else {
                out <- tagList(
                  tags$img(src = desc$images[cap_index],
                           width = v$width))
              }
            } else if (desc$body_index[number] == "break") {
              out <- tagList(tags$text(HTML("</br>"), 
                                       style = "font-size:14px;"))
            }
            return(out)
          }
          tl <- tagList()
          for (i in 1:length(desc$body)){
            tl <- append(tl, tag_list(i))
          }
          tl <- paste('<meta charset="UTF-8">', tagList(tl))
          HTML(tl)
        })
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
      selectA <- v$actual %>% filter(Name == click)
      selectR <- v$restored %>% filter(Name == click)
      
      #zoom to selected feature
      focus <- st_bbox(rbind(selectA, selectR)) %>% as.vector()
      fitBounds(leafletProxy("map"), focus[1], focus[2], focus[3], focus[4])
    }
  })
  
  #reset to all features on button click
  observeEvent(input$reset, { # reset selectInput
    updateSelectInput(session, "features", selected="")
    fitBounds(leafletProxy("map"), 25.52876, 40.49953, 25.53177, 40.50177)
  })
}

shinyApp(ui, server)
