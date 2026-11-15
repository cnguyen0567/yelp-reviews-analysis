## Library =====================================================================
source("scripts/config.R")

## read in new orlean data =====================================================
business_loaded <- readRDS(business_filtered_rds)
review_loaded <- readRDS(review_filtered_rds)


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


# Categories Analysis (uncomment if needed) ====================================
# List of categories and # of available data
category_counts <- business_categories_by_row |>
  count(category, sort = TRUE)
print(category_counts, n = 70)


# Check which restaurants have the selected categories (summarised by restaurant)
selected_categories <- business_categories_by_row |>
  group_by(business_id, business_name) |>
  summarise(
    has_vegetarian = any(category == "Vegetarian"),
    has_vegan = any(category == "Vegan"),
    has_falafel = any(category == "Falafel"),
    has_bagel = any(category == "Bagels"),
    has_salad = any(category == "Salad"),
    has_cafe = any(category == "Cafes"),
    .groups = "drop"
  )

# Count # of restaurants match the chosen categories
# selected_categories |>
#   summarise(
#     any = sum(has_vegetarian | has_vegan | has_falafel | has_bagel),
#     vegetarian_only = sum(has_vegetarian & !has_vegan & !has_falafel & !has_bagel & !has_salad & !has_cafe),
#     vegan_only = sum(!has_vegetarian & has_vegan & !has_falafel & !has_bagel & !has_salad & !has_cafe),
#     falafel_only = sum(!has_vegetarian & !has_vegan & has_falafel & !has_bagel & !has_salad & !has_cafe),
#     bagel_only = sum(!has_vegetarian & !has_vegan & !has_falafel & has_bagel & !has_salad & !has_cafe),
#     salad_only = sum(!has_vegetarian & !has_vegan & !has_falafel & !has_bagel & has_salad & !has_cafe),
#     cafe_only = sum(!has_vegetarian & !has_vegan & !has_falafel & !has_bagel & !has_salad & has_cafe)
#   )
# 
# # Print sample businesses with categories
# business_loaded |>
#   filter(str_detect(categories, regex("cafe", ignore_case = TRUE))) |>
#   select(business_name, categories) |>
#   distinct() |>
#   slice_head(n = 40) |>
#   print()


# Final selection ==============================================================
# See config.R

