## Library =====================================================================
library(tidyverse)
library(jsonlite)
library(lubridate)
library(sf)
library(tigris)
library(scales)
library(viridis)
library(dplyr)
library(stringr)
library(ggplot2)    #For formatting reports
library(patchwork)
library(knitr)
library(tibble)
library(tidyr)
library(DT)
library(ggiraph)
library(ggupset)

library(DBI)      #For download data
library(duckdb)


options(tigris_use_cache = TRUE)


# Constants Variables
selected_state <- "LA"
selected_city <- "New Orleans"
selected_establishment <- "Restaurants"

business_raw_json <- "data/raw/yelp_academic_dataset_business.json"
review_raw_json <- "data/raw/yelp_academic_dataset_review.json"
user_raw_json <- "data/raw/yelp_academic_dataset_user.json"

business_filtered_rds <- "data/new_orleans/business_new_orleans.rds"
review_filtered_rds <- "data/new_orleans/reviews_new_orleans.rds"
user_filtered_rds <- "data/new_orleans/user_new_orleans.rds"

business_selected_rds  <- "data/new_orleans/selected_businesses_geo.rds"
boundaries_selected_rds  <- "data/new_orleans/selected_boundaries.rds"


data_folder = "data/new_orleans"

selected_categories <- c("Vegetarian", "Vegan", "Falafel", "Bagels")
selected_geo <- "ZIP/ZCTA"

