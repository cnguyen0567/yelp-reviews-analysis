## Library =====================================================================
source("scripts/config.R")

## Importing raw data ==========================================================
business_raw <- jsonlite::stream_in(
  file(business_raw_json),
  verbose = FALSE
)

business <- business_raw |>
  select(
    business_id, name, address, city, state, postal_code,
    latitude, longitude, stars, review_count, categories
  )

review_raw <- jsonlite::stream_in(
  file(review_raw_json),
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
  mutate(                                      #add columns:
    postal_code = na_if(postal_code, ""),      #-> blank n/a zip code
    categories = str_squish(categories),       #-> remove white space from categories 
    business_name = str_squish(name)           #-> remove white space from business name
  ) |>
  distinct(business_id, .keep_all = TRUE)      #remove duplicate business_id row


new_orleans_restaurants |>                     #data check for # of records with missing info
  summarise(
    number_of_restaurants = n(),
    missing_latitude = sum(is.na(latitude)),
    missing_longitude = sum(is.na(longitude)),
    missing_categories = sum(is.na(categories))
  )


## Filter reviews for filtered restaurants (by business_id) ====================
new_orleans_reviews <- reviews |>
  semi_join(new_orleans_restaurants, by = "business_id")     #semi_join doesn't add columns from restaurants, just filter


## Save filtered data as RDS ===================================================
# Create directory if not available
dir.create(data_folder, recursive = TRUE, showWarnings = FALSE)

# save the RDS file
saveRDS(
  new_orleans_restaurants,
  business_filtered_rds,
  compress = "xz"
)


saveRDS(
  new_orleans_reviews,
  review_filtered_rds,
  compress = "xz"
)
