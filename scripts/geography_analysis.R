source("scripts/config.R")

## read in new orlean data =====================================================
business_loaded <- readRDS(business_filtered_rds)
review_loaded <- readRDS(review_filtered_rds)


# Filtered data ================================================================
# Filtered restaurant (if categories contain >= 1 selected category)
selected_categories_normalized <- selected_categories |>
  str_squish() |>
  str_to_lower()

selected_businesses <- business_loaded |>
  mutate(
    has_selected_category = purrr::map_lgl(
      str_split(coalesce(categories, ""), pattern = ","),
      \(category_list) {
        category_list_normalized <- category_list |>
          str_squish() |>
          str_to_lower()
        
        any(category_list_normalized %in% selected_categories_normalized)
      }
    )
  ) |>
  filter(has_selected_category) |>
  select(-has_selected_category)


# Filtered review data
selected_reviews <- review_loaded |>
  semi_join(selected_businesses, by = "business_id")



# Load Louisiana Geographic Boundaries =========================================
# LA State
louisiana_places <- tigris::places(
  state = "LA",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# Census Tract
la_tracts <- tigris::tracts(
  state = "LA",
  county = "Orleans",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# Neighborhood Statistical Areas
nola_neighborhoods <- st_read(
  "data/new_orleans/neighborhoods_area_20261110.geojson"
)

# Zip
louisiana_zctas <- tigris::zctas(
  year = 2020,
  cb = TRUE,
  class = "sf"
) |>
  st_transform(st_crs(louisiana_places)) |>
  st_filter(
    tigris::states(cb = TRUE, year = 2020) |>
      filter(STUSPS == "LA") |>
      st_transform(st_crs(louisiana_places))
  )


# Geography Analysis ===========================================================
# A. Function to map and summarize restaurants data for the specified geo area
map_restaurants <- function(
    restaurants,
    boundaries,
    area_col,
    area_id,
    map_title = "Yelp Restaurants by Geographic Area",
    min_restaurants = 5
) {
  
  # 1.Convert restaurant coordinates into spatial points
  restaurant_points <- restaurants |>
    filter(!is.na(longitude), !is.na(latitude)) |>
    st_as_sf(
      coords = c("longitude", "latitude"),
      crs = 4326,
      remove = FALSE
    )
  
  # 2.Transform geo boundaries to match restaurant CRS
  boundaries <- boundaries |>
    st_transform(st_crs(restaurant_points)) |>
    rename(
      area_id = {{ area_id }},
      area_name = {{ area_col }}
    )
  
  
  # 3.Spatially join restaurants with geographic areas
  restaurants_with_area <- restaurant_points |>
    st_join(
      boundaries |>
        select(area_id, area_name),
      join = st_within,
      left = TRUE
    )
  
  
  # 4a.Summarize restaurants and reviews for each boundary area defined by the geo system
  area_summary <- restaurants_with_area |>
    st_drop_geometry() |>
    filter(!is.na(area_id)) |>
    group_by(area_id, area_name) |>
    summarise(
      n_restaurants = n_distinct(business_id),
      avg_rating = mean(stars, na.rm = TRUE),
      median_rating = median(stars, na.rm = TRUE),
      
      weighted_rating = {
        valid <- !is.na(stars) &
          !is.na(review_count) &
          review_count > 0
        
        if (any(valid)) {
          weighted.mean(
            stars[valid],
            w = review_count[valid]
          )
        } else {
          NA_real_
        }
      },
      .groups = "drop"
    )
  
  # 4b.Update area_summary to include geographic areas with zero restaurants
  area_summary <- boundaries |>                                #original boundary table
    left_join(                                                 #left join area_summary table above ...
      area_summary,                                            # ... to pull in restaurants summary data for all areas in the boundary system
      by = c("area_id", "area_name")
    ) |>
    mutate(
      n_restaurants = replace_na(n_restaurants, 0L),           #area w/ no restaurant: enter value 0
      area_sqmi = as.numeric(st_area(geometry)) / 2589988.11,  #calc the area metric
      restaurants_per_sqmi = if_else(                          #restaurant density (# of rest / sq.mi.)
        n_restaurants > 0 & area_sqmi > 0,
        n_restaurants / area_sqmi,
        NA_real_
      )
    )
  
  
  
  # 5a.Geography system summary: Evaluate geographic coverage
  coverage <- restaurants_with_area |>
    st_drop_geometry() |>
    summarise(
      total_restaurants = n_distinct(restaurants$business_id), #total # of restaurants
      
      restaurants_w_missing_coord = total_restaurants -        #Num of rests can't be mapped to a coordinate
        n_distinct(restaurant_points$business_id),
      
      matched_restaurants = n_distinct(                        #Num of rests mapped to a specified boundary area
        business_id[!is.na(area_id)]
      ),
      unmatched_restaurants = n_distinct(                      #Num of rests not mapped to any boundary area
        business_id[is.na(area_id)]
      )
    )
  
  
  # 5b.Geography system summary: Evaluate sample size by geography system + coverage
  geo_system_summary <- area_summary |>
    summarise(
      # Statistics on the boundary areas of the geo system
      total_areas = n(),                                             #Num of boundary areas in this geo system
      avg_sqmi = mean(area_sqmi),
      median_sqmi = median(area_sqmi),
      empty_areas = sum(n_restaurants == 0),                         #Num of areas with no restaurants w/ selected categories
      
      # Statistics on restaurant density
      min_density = min(restaurants_per_sqmi, na.rm = TRUE),
      q25_density = quantile(restaurants_per_sqmi, 0.25, na.rm = TRUE),
      median_density = median(restaurants_per_sqmi, na.rm = TRUE),
      mean_density = mean(restaurants_per_sqmi, na.rm = TRUE),
      q75_density = quantile(restaurants_per_sqmi, 0.75, na.rm = TRUE),
      max_density = max(restaurants_per_sqmi, na.rm = TRUE),
      
      sparse_areas = sum(                                            #Num of areas with low number of restaurants w selected categories
        restaurants_per_sqmi > 0 &
        restaurants_per_sqmi < median_density,
        na.rm = TRUE
      ),
      
      # Statistics on number of restaurants in a boundary
      min_restaurants = min(n_restaurants[n_restaurants > 0]),                    #Min
      q25_restaurants = quantile(n_restaurants[n_restaurants > 0], probs = 0.25), #25th quantile
      median_restaurants = median(n_restaurants[n_restaurants > 0]),              #Med
      mean_restaurants = mean(n_restaurants[n_restaurants > 0]),                  #Avg
      q25_restaurants = quantile(n_restaurants[n_restaurants > 0], probs = 0.75), #75th quantile
      max_restaurants = max(n_restaurants[n_restaurants > 0])                     #Max
    ) |>
    bind_cols(coverage)
  
  
  # 6a. Map: Restaurant location map
  location_map <- ggplot() +
    geom_sf(
      data = boundaries,
      fill = "grey95",
      color = "grey35"
    ) +
    geom_sf(
      data = restaurants_with_area,
      aes(color = stars),
      alpha = 0.65,
      size = 1
    ) +
    scale_color_viridis_c(
      option = "C",
      limits = c(1, 5)
    ) +
    labs(
      title = map_title,
      color = "Yelp Rating"
    ) +
    theme_minimal()
  
  
  # 6b. Map: Restaurant count map
  count_map <- ggplot(area_summary) +
    geom_sf(
      aes(fill = n_restaurants),
      color = "white",
      linewidth = 0.2
    ) +
    scale_fill_viridis_c(
      option = "C"
    ) +
    labs(
      title = paste(map_title, "- Restaurant Counts"),
      fill = "Restaurants"
    ) +
    theme_minimal()
  
  
  # 6c. Average rating map
  rating_map <- ggplot(area_summary) +
    geom_sf(
      aes(fill = avg_rating),
      color = "white",
      linewidth = 0.2
    ) +
    scale_fill_viridis_c(
      option = "C",
      limits = c(1, 5),
      na.value = "grey90"
    ) +
    labs(
      title = paste(map_title, "- Average Rating"),
      fill = "Avg. Rating"
    ) +
    theme_minimal()
  
  
  # 7. Return results
  list(
    restaurants = restaurants_with_area,
    area_summary = area_summary,
    geo_system_summary = geo_system_summary,
    location_map = location_map,
    count_map = count_map,
    rating_map = rating_map
  )
}

# B. Call the functions for various geo areas
tracts_result <- map_restaurants(
  restaurants = selected_businesses,
  boundaries = la_tracts,
  area_col = NAMELSAD,
  area_id = GEOID,
  map_title = "New Orleans Census Tracts"
)

neighborhood_result <- map_restaurants(
  restaurants = selected_businesses,
  boundaries = nola_neighborhoods,
  area_col = gnocdc_lab,
  area_id = neigh_id,
  map_title = "New Orleans Neighborhoods"
)

zip_result <- map_restaurants(
  restaurants = selected_businesses,
  boundaries = louisiana_zctas,
  area_col = NAME20,
  area_id = GEOID20,
  map_title = "New Orleans Postal Code"
)

# Results ======================================================================
# tracts_result$geo_system_summary
# tracts_result$area_summary |>
#   filter(n_restaurants > 4)
# 
# neighborhood_result$geo_system_summary
# neighborhood_result$area_summary |>
#   filter(n_restaurants > 3)
# 
# zip_result$geo_system_summary
# zip_result$area_summary |>
#   filter(n_restaurants > 4)
