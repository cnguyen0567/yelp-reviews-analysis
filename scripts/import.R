library(tidyverse)
library(jsonlite)
library(lubridate)
library(sf)
library(tigris)
library(scales)
library(viridis)

options(tigris_use_cache = TRUE)


business_file <- "data/raw/yelp_academic_dataset_business.json"
review_file <- "data/raw/yelp_academic_dataset_review.json"

business_raw <- jsonlite::stream_in(
  file(business_file),
  verbose = FALSE
)

business <- business_raw |>
  select(
    business_id, name, address, city, state, postal_code,
    latitude, longitude, stars, review_count, categories
  )

review_raw <- jsonlite::stream_in(
  file(review_file),
  verbose = FALSE
)

reviews <- review_raw |>
  select(business_id, user_id, stars, date, text, useful, funny, cool)


dim(business)
dim(reviews)
glimpse(business)
glimpse(reviews)
head(business, 3)