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


## read in new orlean data =====================================================
business_loaded <- readRDS("./data/new_orleans/business_new_orleans.rds")
review_loaded <- readRDS("./data/new_orleans/reviews_new_orleans.rds")


# Extract and disaggregate business categories =================================
business_categories_by_row <- business_loaded |>
  select(business_id, business_name, address, postal_code, latitude, longitude, stars, review_count, categories) |>
  filter(!is.na(categories)) |>
  separate_rows(categories, sep = ",") |>
  mutate(
    category = categories |>
      str_squish() |>
      str_to_lower() |>
      str_to_title()
  ) |>
  select(-categories) |>
  distinct(business_id, category, .keep_all = TRUE)       #keep_all keeps the other columns


# # Categories Analysis (uncomment if needed) ====================================
# # List of categories and # of available data
# category_counts <- business_categories_by_row |>
#   count(category, sort = TRUE)
# print(category_counts, n = 70)
# 
# 
# # Check which restaurants have the selected categories (summarised by restaurant)
# selected_categories <- business_categories_by_row |>
#   group_by(business_id, business_name) |>
#   summarise(
#     has_vegetarian = any(category == "Vegetarian"),
#     has_vegan = any(category == "Vegan"),
#     has_gf = any(category == "Gluten-Free"),
#     .groups = "drop"
#   )
# 
# # Count # of restaurants match the chosen categories
# selected_categories |>
#   summarise(
#     all = sum(has_gf & has_vegetarian & has_vegan),
#     vegan_n_vegetarian = sum(has_vegetarian & has_vegan),
#     vegetarian_only = sum(!has_gf & has_vegetarian & !has_vegan),
#     vegan_only = sum(!has_gf & !has_vegetarian & has_vegan),
#     gf_only = sum(has_gf & !has_vegetarian & !has_vegan)
#   )
# 
# # Print sample businesses with categories
# business_loaded |>
#   filter(str_detect(categories, regex("vegetarian|vegan|gluten free", ignore_case = TRUE))) |>
#   select(business_name, categories) |>
#   distinct() |>
#   slice_head(n = 20) |>
#   print()


# Final selection ==============================================================
selected_categories <- c("Vegetarian", "Vegan", "Gluten-Free")

