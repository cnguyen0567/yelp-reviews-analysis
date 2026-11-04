## Library =====================================================================
library(tidyverse)
library(jsonlite)
library(lubridate)
library(sf)
library(tigris)
library(scales)
library(viridis)

options(tigris_use_cache = TRUE)

## Importing raw data ==========================================================
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

glimpse(business)
glimpse(reviews)


## Filter restaurant for new orleans ===========================================
new_orleans_restaurants <- business |>
  filter(
    state == "LA",
    city == "New Orleans",
    !is.na(categories),
    str_detect(categories, regex("Restaurants", ignore_case = TRUE))
  ) |>
  mutate(
    postal_code = na_if(postal_code, ""),
    categories = str_squish(categories),
    business_name = str_squish(name)
  ) |>
  distinct(business_id, .keep_all = TRUE)                             #remove duplicate business_id row

new_orleans_restaurants |>
  summarise(
    number_of_restaurants = n(),
    missing_latitude = sum(is.na(latitude)),
    missing_longitude = sum(is.na(longitude)),
    missing_categories = sum(is.na(categories))
  )


## Filter reviews for filtered restaurants (by business_id) ===================
new_orleans_reviews <- reviews |>
  semi_join(new_orleans_restaurants, by = "business_id")     #semi_join doesn't add columns from restaurants, just filter


## Save filtered data as RDS ===================================================
# Create directory if not available
folder = "data/new_orleans"
dir.create(folder, recursive = TRUE, showWarnings = FALSE)

# save the RDS file
saveRDS(
  new_orleans_restaurants,
  "data/new_orleans/business_new_orleans.rds",
  compress = "xz"
)


saveRDS(
  new_orleans_reviews,
  "data/new_orleans/reviews_new_orleans.rds",
  compress = "xz"
)

# read it back in later
new_orleans_restaurants_loaded <- readRDS("data/new_orleans/business_new_orleans.rds")