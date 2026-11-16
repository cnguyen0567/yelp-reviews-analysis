## Library =====================================================================
source("scripts/config.R")

## read in new orlean data =====================================================
business_loaded <- readRDS(business_filtered_rds)


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


# Categories Analysis ==========================================================
# List of categories and # of available data
category_counts <- business_categories_by_row |>
  count(category, sort = TRUE)
print(category_counts, n = 70)


# Check which restaurants have the selected categories (summarised by restaurant)
category_summary_by_business <- business_categories_by_row |>
  group_by(business_id, business_name) |>
  summarise(
    has_vegetarian = any(category == "Vegetarian"),
    has_vegan = any(category == "Vegan"),
    has_falafel = any(category == "Falafel"),
    has_bagel = any(category == "Bagels"),
    has_salad = any(category == "Salad"),
    .groups = "drop"
  )

# Count # of restaurants match the chosen categories
category_summary <- category_summary_by_business |>
  summarise(
    any = sum(has_vegetarian | has_vegan | has_falafel | has_bagel),
    vegetarian_only = sum(has_vegetarian & !has_vegan & !has_falafel & !has_bagel & !has_salad),
    vegan_only = sum(!has_vegetarian & has_vegan & !has_falafel & !has_bagel & !has_salad),
    falafel_only = sum(!has_vegetarian & !has_vegan & has_falafel & !has_bagel & !has_salad),
    bagel_only = sum(!has_vegetarian & !has_vegan & !has_falafel & has_bagel & !has_salad),
    salad_only = sum(!has_vegetarian & !has_vegan & !has_falafel & !has_bagel & has_salad),
    vege_vegan_bagel = sum(has_vegetarian & has_vegan & !has_falafel & has_bagel & !has_salad),
    vege_vegan_falafel = sum(has_vegetarian & has_vegan & has_falafel & !has_bagel & !has_salad),
    vegan_falafel_bagel = sum(!has_vegetarian & has_vegan & has_falafel & has_bagel & !has_salad),
    vege_vegan_falafel_bagel = sum(has_vegetarian & has_vegan & has_falafel & has_bagel & !has_salad)
  )

# # Print sample businesses with categories
# business_loaded |>
#   filter(str_detect(categories, regex("Vegetarian", ignore_case = TRUE))) |>
#   select(business_name, categories) |>
#   distinct() |>
#   slice_head(n = 30) |>
#   print()


# Final selection ==============================================================
# See config.R

