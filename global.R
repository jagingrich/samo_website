library(shiny)
library(leaflet)
library(leafem)
library(tidyverse)
library(sf)
library(raster)
library(readxl)
library(officer)
library(shinyjs)
library(imager)

#setting directory
#setwd("/Volumes/Samsung 1TB/Samothrace/Samothrace 2023/AES Work/Web/Leaflet/Samo_web")

#reading basemap file
bm_file <- list.files("./Data/", pattern = "tif")
bm_file <- bm_file[grep("3857", bm_file, invert=F)]
bm_actual <- stack(paste0("./Data/", bm_file[grep("Actual", bm_file, invert=F)]))
bm_restored <- stack(paste0("./Data/", bm_file[grep("Restored", bm_file, invert=F)]))
extent <- extent(projectRaster(bm_actual, crs = '+proj=longlat +datum=WGS84'))

#reading monuments .gpkg file
mt_file <- list.files("./Data/", pattern = "gpkg")
mt_file <- mt_file[grep("wal|shm", mt_file, invert=T)]
mt_file <- mt_file[grep("AES", mt_file, invert=F)]
layers <- st_layers(paste0("./Data/", mt_file))
mt_actual <- read_sf(paste0("./Data/", mt_file), layer = layers$name[grep("Actual", layers$name)]) %>%
  mutate(ID = paste0(ID, "A")) %>%
  st_transform('+proj=longlat +datum=WGS84')
mt_restored <- read_sf(paste0("./Data/", mt_file), layer = layers$name[grep("Restored", layers$name)]) %>%
  mutate(ID = paste0(ID, "R")) %>%
  st_transform('+proj=longlat +datum=WGS84')
st_geometry(mt_actual) <- "geometry"
st_geometry(mt_restored) <- "geometry"

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

#reading descriptions files
text_file <- list.files(paste0("./Data/Descriptions/"), pattern = ".docx")
mt_files <- vector()
mt_files_num <- vector()
for (i in 1:length(text_file)) {
  filex <- trimws(unlist(strsplit(text_file[i], "_"))[3])
  mt_files[i] <- filex
  mt_files_num[i] <- unlist(strsplit(filex, "\\(|\\)"))[2]
}

files <- data.frame("Labels" = mt_files_num, "File_ID" = mt_files)

descriptions <- data.frame("Names" = c("(0) Introduction", mt_names), 
                           "Labels" = c("0", mt_labels), 
                           "Full_Name" = NA,
                           "Header" = NA,
                           "Body1" = NA, "Image1" = NA, "Caption1" = NA,
                           "Body2" = NA, "Image2" = NA, "Caption2" = NA,
                           "Body3" = NA, "Image3" = NA, "Caption3" = NA,
                           "Body4" = NA, "Image4" = NA, "Caption4" = NA,
                           "Body5" = NA, "Image5" = NA, "Caption5" = NA,
                           "Body6" = NA, "Image6" = NA, "Caption6" = NA,
                           "Body7" = NA, "Image7" = NA, "Caption7" = NA,
                           "Body8" = NA, "Image8" = NA, "Caption8" = NA,
                           "Body9" = NA, "Image9" = NA, "Caption9" = NA,
                           "Body10" = NA, "Image10" = NA, "Caption10" = NA,
                           "Footer" = NA)

descriptions <- merge(files, descriptions, by="Labels", all=T)

for (i in mt_files) {
  text_file_i <- text_file[grep(paste0("\\", i), text_file)]
  
  text <- read_docx(paste0("./Data/Descriptions/", text_file_i))
  text <- docx_summary(text)
  
  #need to tag the monument name, date, material, and location for this to read properly
  remove <- "\\[image|Title:|Monument:|Part:|Date:|Material:|Location:|Caption:|INCLUDEPICTURE|Bibliography"
  
  name <- text$text[grep("Monument:|Title:", text$text)]
  name <- gsub("Monument: |Title: ", "", name)
  name <- paste0("<b>", name, "</b>")
  intro <- text$text[grep("Part:|Date:|Material:|Location:", text$text)]
  intro <- ifelse(grepl("Part:", intro), paste0("<b>", intro, "</b>"), intro)
  intro <- gsub("Part: ", "</br>", intro)
  intro <- gsub("Date: |Material: |Location: ", "", intro)
  header <- paste(c(intro), sep='</br>', collapse ='</br>')
  
  bibliotext <- text$doc_index[grep("Bibliography", text$text)]
  if(length(bibliotext != 0)) {
    biblio <- text %>% filter(doc_index > bibliotext,
                              text != "") %>% pull(text)
    biblio <- biblio[grep("Document updated:|JAG_UNEDITED", biblio, invert = T, ignore.case = T)]
    footer <- paste(c("<b>Selected Bibliography</b>", biblio), sep='</br>', collapse ='</br>')
  }
  else {
    footer <- NA
  }
  captions <- vector("character", 10)
  if(length(text$text[grep("Caption:", text$text)]) > 0) {
    captions[1:length(text$text[grep("Caption:", text$text)])] <- text$text[grep("Caption:", text$text)]
  }
  captions[captions == ""] <- NA
  captions <- gsub("Caption: ", "", captions)
  
  captionbreaks1 <- c(0, text$doc_index[grep("Caption:", text$text)])
  captionbreaks2 <- c(text$doc_index[grep("Caption:", text$text)], min(c(bibliotext, max(text$doc_index)), na.rm=T))
  
  body <- vector("character", 10)
  for (j in 1:length(captionbreaks1)) {
    range <- captionbreaks1[j]:captionbreaks2[j]
    body_sub <- text %>% filter(doc_index %in% range,
                                text != "",
                                !grepl(remove, text, ignore.case=T)) %>%
      pull(text)
    body[j] <- paste(body_sub , sep='</br></br>', collapse ='</br></br>')
  }
  body[body == ""] <- NA
  
  #reading images to match captions
  img_files <- list.files(paste0("./www/Caption_Images/"), pattern = ".jp|.png|.tif")
  img_files <- img_files[grep(paste0("\\", i), img_files)]
  imgs <- data.frame(CaptionNum = c(1:10), Images = NA)
  if(length(img_files) != 0) {
    imgs <- data.frame(Images = img_files)
    for (j in 1:length(imgs$Images)) {
      num <- trimws(unlist(strsplit(imgs$Images[j], "_"))[4])
      imgs$CaptionNum[j] <- as.numeric(gsub("Image|.jpg|.jpeg|.png", "", num, ignore.case = T))
    }
  } 
  #Caption numbers
  imgs <- merge(data.frame(Monument = i, CaptionNum = c(1:10)), imgs, by="CaptionNum", all=T)
  
  list_num <- unlist(strsplit(i, "\\(|\\)"))[2]
  
  descriptions <- descriptions %>%
    mutate(Full_Name = ifelse(Labels == list_num, name, Full_Name),
           Header = ifelse(Labels == list_num, header, Header),
           Body1 = ifelse(Labels == list_num, body[1], Body1),
           Body2 = ifelse(Labels == list_num, body[2], Body2),
           Body3 = ifelse(Labels == list_num, body[3], Body3),
           Body4 = ifelse(Labels == list_num, body[4], Body4),
           Body5 = ifelse(Labels == list_num, body[5], Body5),
           Body6 = ifelse(Labels == list_num, body[6], Body6),
           Body7 = ifelse(Labels == list_num, body[7], Body7),
           Body8 = ifelse(Labels == list_num, body[8], Body8),
           Body9 = ifelse(Labels == list_num, body[9], Body9),
           Body10 = ifelse(Labels == list_num, body[10], Body10),
           Image1 = ifelse(Labels == list_num, imgs$Images[1], Image1),
           Image2 = ifelse(Labels == list_num, imgs$Images[2], Image2),
           Image3 = ifelse(Labels == list_num, imgs$Images[3], Image3),
           Image4 = ifelse(Labels == list_num, imgs$Images[4], Image4),
           Image5 = ifelse(Labels == list_num, imgs$Images[5], Image5),
           Image6 = ifelse(Labels == list_num, imgs$Images[6], Image6),
           Image7 = ifelse(Labels == list_num, imgs$Images[7], Image7),
           Image8 = ifelse(Labels == list_num, imgs$Images[8], Image8),
           Image9 = ifelse(Labels == list_num, imgs$Images[9], Image9),
           Image10 = ifelse(Labels == list_num, imgs$Images[10], Image10),
           Caption1 = ifelse(Labels == list_num, captions[1], Caption1),
           Caption2 = ifelse(Labels == list_num, captions[2], Caption2),
           Caption3 = ifelse(Labels == list_num, captions[3], Caption3),
           Caption4 = ifelse(Labels == list_num, captions[4], Caption4),
           Caption5 = ifelse(Labels == list_num, captions[5], Caption5),
           Caption6 = ifelse(Labels == list_num, captions[6], Caption6),
           Caption7 = ifelse(Labels == list_num, captions[7], Caption7),
           Caption8 = ifelse(Labels == list_num, captions[8], Caption8),
           Caption9 = ifelse(Labels == list_num, captions[9], Caption9),
           Caption10 = ifelse(Labels == list_num, captions[10], Caption10),
           Footer = ifelse(Labels == list_num, footer, Footer))
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
