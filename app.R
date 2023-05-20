library(shiny)
library(jsonlite)
library(httpuv)
library(httr)
library(leaflet)
library(leafem)
library(tidyverse)
library(sf)
library(shinyjs)

#github repository
oauth_endpoints("github")

# API authorization settings
myapp <- oauth_app(appname = "Samo_Web_Data",
                   key = "#####",
                   secret = "#####")

# Get OAuth credentials
gtoken <- config(token = oauth2.0_token(oauth_endpoints("github"), myapp))
rm(myapp)

#gtoken <- readRDS("./Data/github_token.rds")
gitrepo <- "jagingrich/samo_website"

#reading monuments .gpkg file
gpkg_path <- paste0("https://raw.githubusercontent.com/", gitrepo, "/main/Data/mapFeatures/AES_Monuments_20230207.gpkg")
layers <- st_layers(gpkg_path)
mt_actual <- read_sf(gpkg_path, layer = layers$name[grep("Actual", layers$name)]) %>%
  mutate(ID = paste0(ID, "A")) %>%
  st_transform('+proj=longlat +datum=WGS84')
mt_restored <- read_sf(gpkg_path, layer = layers$name[grep("Restored", layers$name)]) %>%
  mutate(ID = paste0(ID, "R")) %>%
  st_transform('+proj=longlat +datum=WGS84')
st_geometry(mt_actual) <- "geometry"
st_geometry(mt_restored) <- "geometry"
rm(layers)

#cleaning and sorting monument names
mt_actual <- mt_actual %>% 
  mutate(Name = paste0("(", Label, ") ", Name))
mt_restored <- mt_restored %>% 
  mutate(Name = paste0("(", Label, ") ", Name))
mt_names <- rbind(mt_actual, mt_restored) %>%
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

# Use API
req <- GET(paste0("https://api.github.com/repos/", gitrepo, "/git/trees/main?recursive=1"), gtoken)
stop_for_status(req)
ct = content(req)
ct <- ct$tree
rm(req)

pull_data <- function(filterPhrase = NULL, filterInvert = F) {
  #reading all files in tree
  paths <- vector()
  names <- vector()
  types <- vector()
  download_urls <- vector()
  
  for (i in ct) {
    item <- i
    if(grepl("Data", item$path)) {
      paths <- append(paths, item$path)
      name_i <- unlist(strsplit(item$path, "/"))
      name_i <- name_i[length(name_i)]
      names <- append(names, name_i)
      if (item$type == "blob") {
        type_i <- unlist(lapply(strsplit(name_i, "[.]"), `[[`, 2))
      } else {
        type_i <- item$type
      }
      types <- append(types, type_i)
      url_i <- paste0("https://api.github.com/repos/", gitrepo, "/contents/", item$path)
      url_i <- gsub(" ", "%20", url_i)
      download_urls <- append(download_urls, url_i)
      rm(name_i)
      rm(type_i)
      rm(url_i)
    }
    rm(item)
  }
  
  #table of files
  df <- data.frame(name = names, path = paths, type = types, download_url = download_urls) 
  #removing filter phrase matches
  if(!is.null(filterPhrase)) {
    for (i in filterPhrase) {
      df <- df %>%
        filter(path %in% df$path[grep(paste0("\\", i), df$path, invert=filterInvert, ignore.case=T)])
    }
  }
  #remove loading vectors
  rm(names)
  rm(types)
  rm(paths)
  rm(download_urls)
  
  #output
  return(df)
}

#collection names
mt_files <- pull_data(c("mapTiles", "www"), filterInvert = T)
mt_files <- mt_files %>%
  filter(type == "tree",
         path %in% mt_files$path[grep("Data/", mt_files$path)],
         path %in% mt_files$path[grep("mapFeatures|Descriptions", mt_files$path, invert = T)]) %>%
  pull(path)
mt_files <- gsub("Data/", "", mt_files)

#file - monument linking table
crosstab <- merge(data.frame("Labels" = c("0", unlist(lapply(strsplit(mt_names, "\\(|\\)"), `[[`, 2))), "Names" = c("", mt_names)),
                  data.frame("Labels" = unlist(lapply(strsplit(mt_files, "\\(|\\)"), `[[`, 2)), "File_ID" = mt_files), by = "Labels", all=T)

#reading elements from description .txt files
read_txt <- function(filename) {
  #reading description from file on github API
  txts <- pull_data(filename) %>%
    filter(type == "txt")
  req <- GET(txts %>%
               pull(download_url),
             gtoken)
  stop_for_status(req)
  
  txt <- trimws(readLines(content(req)$download_url))
  txt <- txt[txt!=""]
  txt <- txt[txt!="\t"]
  rm(req)
  
  #removing paragraph formatting tags
  remove <- "\\[image|Title:|Monument:|Part:|Date:|Material:|Location:|Caption:|INCLUDEPICTURE|Bibliography"
  
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
  
  #output
  desc_out <- list("name" = name, "header" = header, "body_index" = body_index, "body" = body, "footer" = footer)
  return(desc_out)
}

load_imgs <- function(filename) {
  imgs <- pull_data(c(filename, "Image"))
  img_path <- vector("character", 10)
  if (length(imgs$download_url) != 0) {
    for (i in 1:length(imgs$download_url)) {
      req <- GET(imgs$download_url[i],
                 gtoken)
      img_path[i] <- content(req)$download_url
    }
  }
  img_path[img_path == ""] <- NA
  return(img_path)
}

#Color palette for phases
pal <- c("1" = "#94d1e7",
         "2" = "#007abc",
         "3" = "#00a33c",
         "4" = "#ff871f",
         "5" = "#ff171F",
         "6" = "#fdf500")
pal <- pal[sort(unique(mt_actual$Phase))]
factPal <- colorFactor(pal, mt_actual$Phase)
pn <- st_drop_geometry(mt_actual) %>% dplyr::select(Phase, Phase_Name) %>%
  distinct() %>%
  arrange(Phase) %>%
  pull(Phase_Name)


ui <- fluidPage(
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
                         selectInput("features", label = NULL, choices = c("", mt_names), selected = "", width = "100%")
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

server <- function(input, output, session) {
  #saving screen width value
  v <- reactiveValues(width = NULL,
                      text = NULL,
                      img = NULL) 
  
  #creating map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/AES_ActualStatePlan_3857/{z}/{x}/{y}.png",
               attribution = '<a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
               options = tileOptions(minZoom = 16, maxZoom = 21, tms = TRUE),
               group = "Actual Plan") %>%
      addTiles(urlTemplate = "https://raw.githubusercontent.com/jagingrich/samo_website/main/Data/mapTiles/AES_RestoredStatePlan_3857/{z}/{x}/{y}.png",
               attribution = '<a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
               options = tileOptions(minZoom = 16, maxZoom = 21, tms = TRUE), 
               group = "Restored Plan") %>%
      #monument shapes for the actual state plan
      addPolygons(data = mt_actual %>% filter(!Name %in% mt_names), 
                  color = ~factPal(Phase), weight = 1, opacity = 1, 
                  fillOpacity = 0.8, fillColor = ~factPal(Phase), 
                  layerId = mt_actual %>% filter(!Name %in% mt_names) %>% pull(ID), 
                  group = "Actual Plan") %>%
      addPolygons(data = mt_actual %>% filter(Name %in% mt_names), 
                  color = ~factPal(Phase), weight = 1, opacity = 0.75, 
                  fillOpacity = 0.75, fillColor = ~factPal(Phase), 
                  highlightOptions = highlightOptions(color = ~factPal(Phase), opacity = 0.95, weight=2, 
                                                      fillOpacity = 0.95, bringToFront = T), 
                  layerId = mt_actual %>% filter(Name %in% mt_names) %>% pull(ID), 
                  group = "Actual Plan") %>%
      #monument shapes for the restored state plan
      addPolygons(data = mt_restored %>% filter(!Name %in% mt_names), 
                  color = ~factPal(Phase), weight = 1, opacity = 1, 
                  fillOpacity = 0.8, fillColor = ~factPal(Phase), 
                  layerId = mt_restored %>% filter(!Name %in% mt_names) %>% pull(ID), 
                  group = "Restored Plan") %>%
      addPolygons(data = mt_restored %>% filter(Name %in% mt_names), 
                  color = ~factPal(Phase), weight = 1, opacity = 0.75, 
                  fillOpacity = 0.75, fillColor = ~factPal(Phase), 
                  highlightOptions = highlightOptions(color = ~factPal(Phase), opacity = 0.95, weight=2, 
                                                      fillOpacity = 0.95, bringToFront = T), 
                  layerId = mt_restored %>% filter(Name %in% mt_names) %>% pull(ID), 
                  group = "Restored Plan") %>%
      addLegend("bottomleft", colors = pal, 
                labels = pn, 
                opacity = 1) %>%
      addLayersControl(
        baseGroups = c("Actual Plan", "Restored Plan"),
        options = layersControlOptions(collapsed = FALSE)) %>%
      addControl(actionButton("reset", "All Monuments", style = "font-size:10px;"), 
                 position="topright", className = "leaflet-control-layers-selector")
  })
  
  output$date <- renderUI({HTML("</br>---</br>Plan date: 2016-2019. Dates provided in the legend based on the interpretations by the Lehmanns.")})
  
  observeEvent({
    input$dimension
    input$features
  }, {
    v$width <- paste0(round(input$dimension[1] * 0.38), "px")
  })
  
  observeEvent({
    v$width
  }, {
    proxy <- leafletProxy("map")
    if(input$features == "") { #no selection
      #zoom to all features
      fitBounds(proxy, 25.52876, 40.49953, 25.53177, 40.50177)
    }
  })
  
  
  observeEvent(input$features, { #monitor which feature is selected based on selectInput
    
    #zooming the map
    proxy <- leafletProxy("map")
    
    if(input$features == "") { #no selection
      #zoom to all features
      fitBounds(proxy, 25.52876, 40.49953, 25.53177, 40.50177)
      
    } else { #specific feature selected
      selectA <- mt_actual %>% filter(Name == input$features)
      selectR <- mt_restored %>% filter(Name == input$features)
      
      #zoom to selected feature
      focus <- st_bbox(rbind(selectA, selectR)) %>% as.vector()
      fitBounds(proxy, focus[1], focus[2], focus[3], focus[4])
    }
    
    #decription outputs
    v$text <- read_txt(crosstab %>%
                         filter(Names == input$features) %>%
                         pull(File_ID))
    
    v$img <- load_imgs(crosstab %>%
                         filter(Names == input$features) %>%
                         pull(File_ID))
    
    if(is.na(v$text$name)) {
      hide("title")
    } else {
      output$title <- renderUI({
        HTML(paste0(v$text$name, "</br>"))
      })
      show("title")
    }
    
    if(is.na(v$text$header)) {
      hide("header")
    } else {
      output$header <- renderUI({
        HTML(paste0(v$text$header, "</br>---</br>"))
      })
      show("header")
    }
    
    output$body <- renderUI({
      tag_list <- function(number) {
        if (v$text$body_index[number] == "body") {
          out <- tagList(tags$text(HTML(paste0(v$text$body[number], "</br></br>")), 
                                   style = "font-size:16px;"))
        } else {
          caps <- v$text$body[v$text$body_index == "caption"] 
          cap_index <- (1:length(caps))[caps == v$text$body[number]]
          out <- tagList(
            tags$img(src = v$img[cap_index],
                     width = v$width),
            tags$text(HTML(paste0("</br>", v$text$body[number], "</br></br>")), 
                      style = "font-size:14px;"))
        }
        return(out)
      }
      tl <- tagList()
      for (i in 1:length(v$text$body)){
        tl <- append(tl, tag_list(i))
      }
      tagList(tl)
    })
    
    if(is.na(v$text$footer)) {
      hide("footer")
    } else {
      output$footer <- renderUI({
        HTML(paste0("</br>---</br>", v$text$footer, "</br></br>"))
      })
      show("footer")
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
      click <- unique(st_drop_geometry(mt_actual) %>%
                        filter(ID %in% feat$id) %>%
                        pull(Name))
    }
    if(feat$group == "Restored Plan") {
      click <- unique(st_drop_geometry(mt_restored) %>%
                        filter(ID %in% feat$id) %>%
                        pull(Name))
    }
    if(click %in% mt_names) {
      updateSelectInput(session, "features", selected=click)
    }
  })
  
  #reset to all features on button click
  observeEvent(input$reset, { # reset selectInput
    updateSelectInput(session, "features", selected="")
  })
}

shinyApp(ui, server)
