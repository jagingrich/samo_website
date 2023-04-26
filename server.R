library(shiny)

function(input, output, session) {
  #creating map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles(urlTemplate = "",
               #urlTemplate = "http://github.com/jagingrich/mapTiles/tree/main/AES_ActualStatePlan_3857/{z}/{x}/{y}.png",
               #urlTemplate = "http://jagingrich.github.io/mapTiles/AES_ActualStatePlan_3857/{z}/{x}/{y}.png",
               attribution = '<a href="https://www.samothrace.emory.edu/">American Excavations Samothrace',
               options = tileOptions(minZoom = 16, maxZoom = 21, tms = TRUE)) %>%
      addRasterRGB(bm_actual, r = 1, g = 2, b = 3, group = "Actual Plan") %>%
      addRasterRGB(bm_restored, r = 1, g = 2, b = 3, group = "Restored Plan") %>%
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
  
  observe({ #monitor which feature is selected based on selectInput
    proxy <- leafletProxy("map")
    
    input$features
    if(input$features == "") { #no selection
      #panel text
      textDesc <- descriptions %>% filter(Labels == "0")
      
      #zoom to all features
      fitBounds(proxy, extent[1], extent[3], extent[2], extent[4])
      
    } else { #specific feature selected
      selectA <- mt_actual %>% filter(Name == input$features)
      selectR <- mt_restored %>% filter(Name == input$features)
      
      #panel text
      mt_label <- unique(c(selectA$Label, selectR$Label))
      textDesc <- descriptions %>% filter(Labels == mt_label)
      
      #zoom to selected feature
      focus <- st_bbox(rbind(selectA, selectR)) %>% as.vector()
      fitBounds(proxy, focus[1], focus[2], focus[3], focus[4])
    }
    #outputs
    if(is.na(textDesc$Full_Name)) {
      hide("title")
    } else {
      output$title <- renderUI({
        HTML(paste0(textDesc$Full_Name, "</br>"))
      })
      show("title")
    }
    
    if(is.na(textDesc$Header)) {
      hide("header")
    } else {
      output$header <- renderUI({
        HTML(paste0(textDesc$Header, "</br>---</br>"))
      })
      show("header")
    }
    
    if(is.na(textDesc$Body1)) {
      hide("body1")
    } else {
      output$body1 <- renderUI({
        HTML(paste0(textDesc$Body1, "</br></br>"))
      })
      show("body1")
    }
    
    if(is.na(textDesc$Body2)) {
      hide("body2")
    } else {
      output$body2 <- renderUI({
        HTML(paste0(textDesc$Body2, "</br></br>"))
      })
      show("body2")
    }
    
    if(is.na(textDesc$Body3)) {
      hide("body3")
    } else {
      output$body3 <- renderUI({
        HTML(paste0(textDesc$Body3, "</br></br>"))
      })
      show("body3")
    }
    
    if(is.na(textDesc$Body4)) {
      hide("body4")
    } else {
      output$body4 <- renderUI({
        HTML(paste0(textDesc$Body4, "</br></br>"))
      })
      show("body4")
    }
    
    if(is.na(textDesc$Body5)) {
      hide("body5")
    } else {
      output$body5 <- renderUI({
        HTML(paste0(textDesc$Body5, "</br></br>"))
      })
      show("body5")
    }
    
    if(is.na(textDesc$Body6)) {
      hide("body6")
    } else {
      output$body6 <- renderUI({
        HTML(paste0(textDesc$Body6, "</br></br>"))
      })
      show("body6")
    }
    
    if(is.na(textDesc$Body7)) {
      hide("body7")
    } else {
      output$body7 <- renderUI({
        HTML(paste0(textDesc$Body7, "</br></br>"))
      })
      show("body7")
    }
    
    if(is.na(textDesc$Body8)) {
      hide("body8")
    } else {
      output$body8 <- renderUI({
        HTML(paste0(textDesc$Body8, "</br></br>"))
      })
      show("body8")
    }
    
    if(is.na(textDesc$Body9)) {
      hide("body9")
    } else {
      output$body9 <- renderUI({
        HTML(paste0(textDesc$Body9, "</br></br>"))
      })
      show("body9")
    }
    
    if(is.na(textDesc$Body10)) {
      hide("body10")
    } else {
      output$body10 <- renderUI({
        HTML(paste0(textDesc$Body10, "</br></br>"))
      })
      show("body10")
    }
    
    if(!is.na(textDesc$Caption1) & !is.na(textDesc$Image1)) {
      output$image1 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image1),
             width="500px")
      }, deleteFile = F)
      output$caption1 <- renderUI({
        HTML(paste0(textDesc$Caption1, "</br></br>"))
      })
      show("image1")
      show("caption1")
    } else {
      hide("image1")
      hide("caption1")
    }
    
    if(!is.na(textDesc$Caption2) & !is.na(textDesc$Image2)) {
      output$image2 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image2),
             width="500px")
      }, deleteFile = F)
      output$caption2 <- renderUI({
        HTML(paste0(textDesc$Caption2, "</br></br>"))
      })
      show("image2")
      show("caption2")
    } else {
      hide("image2")
      hide("caption2")
    }
    
    if(!is.na(textDesc$Caption3) & !is.na(textDesc$Image3)) {
      output$image3 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image3),
             width="500px")
      }, deleteFile = F)
      output$caption3 <- renderUI({
        HTML(paste0(textDesc$Caption3, "</br></br>"))
      })
      show("image3")
      show("caption3")
    } else {
      hide("image3")
      hide("caption3")
    }
    
    if(!is.na(textDesc$Caption4) & !is.na(textDesc$Image4)) {
      output$image4 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image4),
             width="500px")
      }, deleteFile = F)
      output$caption4 <- renderUI({
        HTML(paste0(textDesc$Caption4, "</br></br>"))
      })
      show("image4")
      show("caption4")
    } else {
      hide("image4")
      hide("caption4")
    }
    
    if(!is.na(textDesc$Caption5) & !is.na(textDesc$Image5)) {
      output$image5 <- renderImage({
      list(src = paste0("www/Caption_Images/", textDesc$Image5),
             width="500px")
      }, deleteFile = F)
      output$caption5 <- renderUI({
        HTML(paste0(textDesc$Caption5, "</br></br>"))
      })
      show("image5")
      show("caption5")
    } else {
      hide("image5")
      hide("caption5")
    }
    
    if(!is.na(textDesc$Caption6) & !is.na(textDesc$Image6)) {
      output$image6 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image6),
             width="500px")
      }, deleteFile = F)
      output$caption6 <- renderUI({
        HTML(paste0(textDesc$Caption6, "</br></br>"))
      })
      show("image6")
      show("caption6")
    } else {
      hide("image6")
      hide("caption6")
    }
    
    if(!is.na(textDesc$Caption7) & !is.na(textDesc$Image7)) {
      output$image7 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image7),
             width="500px")
      }, deleteFile = F)
      output$caption7 <- renderUI({
        HTML(paste0(textDesc$Caption7, "</br></br>"))
      })
      show("image7")
      show("caption7")
    } else {
      hide("image7")
      hide("caption7")
    }
    
    if(!is.na(textDesc$Caption8) & !is.na(textDesc$Image8)) {
      output$image8 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image8),
             width="500px")
      }, deleteFile = F)
      output$caption8 <- renderUI({
        HTML(paste0(textDesc$Caption8, "</br></br>"))
      })
      show("image8")
      show("caption8")
    } else {
      hide("image8")
      hide("caption8")
    }
    
    if(!is.na(textDesc$Caption9) & !is.na(textDesc$Image9)) {
      output$image9 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image9),
             width="500px")
      }, deleteFile = F)
      output$caption9 <- renderUI({
        HTML(paste0(textDesc$Caption9, "</br></br>"))
      })
      show("image9")
      show("caption9")
    } else {
      hide("image9")
      hide("caption9")
    }
    
    if(!is.na(textDesc$Caption10) & !is.na(textDesc$Image10)) {
      output$image10 <- renderImage({
        list(src = paste0("www/Caption_Images/", textDesc$Image10),
             width="500px")
      }, deleteFile = F)
      output$caption10 <- renderUI({
        HTML(paste0(textDesc$Caption10, "</br></br>"))
      })
      show("image10")
      show("caption10")
    } else {
      hide("image10")
      hide("caption10")
    }
    
    if(is.na(textDesc$Footer)) {
      hide("footer")
    } else {
      output$footer <- renderUI({
        HTML(paste0("</br>---</br>", textDesc$Footer, "</br></br>"))
      })
      show("footer")
    }
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