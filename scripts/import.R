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
    latitude, longitude, stars, review_count, categories, is_open
  )

glimpse(business)                               #See fields in business data
unique(business$state)                          #See list of unique state names and their naming convention 
unique(filter(business, state == "LA")$city)    #See list of city names and their naming convention


## Filter restaurant for new orleans ===========================================
# 1. Clean the data:
business_clean <- business |>
  mutate(                                         
    city_standardized = case_when(              #standardize the city field   
      city %in% c(
        "New Orlaens",
        "French Quarter",
        "French Quarter - CBD"
      ) ~ "New Orleans",
      TRUE ~ city
    ) |>
      str_to_lower() |>
      str_remove_all("\\s+"),
    
    postal_code = na_if(postal_code, ""),       #Convert blank ZIP codes to NA
    categories = str_squish(categories),        #remove leading, trailing, and extra blank space from categories
    business_name = str_squish(name)            #remove leading, trailing, and extra blank space from business names
  )


# 2. #Filter business data by state and city
new_orleans_restaurants <- business_clean |>          
  filter(
    state == "LA",
    city_standardized == "neworleans",
    is_open == 1,
    !is.na(categories),
    str_detect(categories, regex("Restaurants", ignore_case = TRUE))
  ) |>
  distinct(business_id, .keep_all = TRUE)      #remove duplicate business_id row

 
# 3. data check for # of records with missing info
new_orleans_restaurants |>
  summarise(
    number_of_restaurants = n(),
    missing_latitude = sum(is.na(latitude)),
    missing_longitude = sum(is.na(longitude)),
    missing_categories = sum(is.na(categories))
  )


## Save filtered data as RDS ===================================================
# Create directory if not available
dir.create(data_folder, recursive = TRUE, showWarnings = FALSE)

# save the RDS file
saveRDS(
  new_orleans_restaurants,
  business_filtered_rds,
  compress = "xz"
)


## Read and Save Review Data ===================================================
# 1. create the restaurant ID list
restaurant_ids <- new_orleans_restaurants |>
  select(business_id)

# 2. Load only the IDs into DuckDB
con <- dbConnect(duckdb::duckdb())

dbWriteTable(
  con,
  "restaurant_ids",
  restaurant_ids,
  temporary = TRUE
)

# 3. Query the rest of the data
review_path_sql <- as.character(
  dbQuoteString(con, normalizePath(review_raw_json))
)

query <- paste0(                                     #query statement. selecting only reviews for business in NO, LA
  "
  SELECT
    r.business_id,
    r.review_id,
    r.user_id,
    r.stars,
    r.date,
    r.text,
    r.useful,
    r.funny,
    r.cool
  FROM read_json_auto(
    ", review_path_sql, ",
    format = 'newline_delimited'
  ) AS r
  SEMI JOIN restaurant_ids AS i
    USING (business_id)
  "
)

new_orleans_reviews <- dbGetQuery(con, query)
# nrow(new_orleans_reviews)
# glimpse(new_orleans_reviews)


# 4. Close the connection
dbDisconnect(con, shutdown = TRUE)

gc()


# 5. Save review to rds
saveRDS(
  new_orleans_reviews,
  review_filtered_rds,
  compress = "xz"
)


## Read and Save User Data ===================================================
# 1. create the user ID list
user_ids <- new_orleans_reviews |>
  select(user_id)

# 2. Load only the IDs into DuckDB
con <- dbConnect(duckdb::duckdb())

dbWriteTable(
  con,
  "user_ids",
  user_ids,
  temporary = TRUE
)

# 3. Query the rest of the data
user_path_sql <- as.character(
  dbQuoteString(con, normalizePath(user_raw_json))
)

query <- paste0(                                     #query statement. selecting only users with review in NOLA
  "
  SELECT
    r.user_id,
    r.review_count,
    r.yelping_since,
    r.average_stars,
    r.elite,
    r.useful + r.funny + r.cool AS vote_count
  FROM read_json_auto(
    ", user_path_sql, ",
    format = 'newline_delimited'
  ) AS r
  SEMI JOIN user_ids AS i
    USING (user_id)
  "
)

new_orleans_users <- dbGetQuery(con, query)


# 4. Close the connection
dbDisconnect(con, shutdown = TRUE)

gc()


# 5. Save review to rds
glimpse(new_orleans_users)

saveRDS(
  new_orleans_users,
  user_filtered_rds,
  compress = "xz"
)