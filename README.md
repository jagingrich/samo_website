# samo_website
# Code and data creating the interactive map plan for the Sanctuary of the Great Gods, Samothrace

Code, text, images, and GIS files that support this Shiny interactive map: Jared Gingrich, May 20, 2023

This repository contains the text and images (.txt and .jpg/.png files) that are read by the web map to load the descriptions that accompany each monument on the plan. Updating or replacing the files in the monument directories found in the Data tree of this repository will update the descriptions of the web map. Adding additional monument directories, named with a unique numeric identifier that matches with a feature on the GIS layers (found in the mapFeatures directory) will add a new description. 

Notes:
* Text description files should be a .txt file, ideally with UTF-8 encoding
* Image files should be in .jpg or .png format
* Image files should all have the same name with a sequential image tag ("Image1", Image2", etc.) that corresponds to the order in which they will be displayed
* The number of image files should correspond to the number of captions in the text description file:
  * If there are fewer captions than images in the monument directory, not all images will be displayed
  * If there are more captions than images in the monument directory, the additional captions will not have images attached
