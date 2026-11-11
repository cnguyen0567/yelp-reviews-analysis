source("scripts/categories_analysis.R")
options(tigris_use_cache = TRUE)


# Filtered restaurant and review data ==========================================
selected_businesses <- business_loaded |>
  semi_join(
    business_categories_by_row |>
      filter(category %in% selected_categories),
    by = "business_id"
  )

selected_reviews <- review_loaded |>
  semi_join(selected_businesses, by = "business_id")


# New Orlean Geo ===============================================================
# Load Louisiana geographic boundaries
louisiana_places <- tigris::places(
  state = "LA",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

# # Convert restaurant coordinates into spatial points
# restaurant_points <- selected_businesses |>
#   filter(!is.na(longitude), !is.na(latitude)) |>               #Filter missing coords
#   st_as_sf(                                                    #Filter missing coordinates
#     coords = c("longitude", "latitude"), 
#     crs = 4326,
#     remove = FALSE                                             #--> keep org coord
#   )
# 
# # Spatially join restaurants with geographic places
# restaurants_with_place <- restaurant_points |>
#   st_join(
#     louisiana_places |>
#       st_transform(st_crs(restaurant_points)) |>
#       select(GEOID, place_name = NAME),
#     join = st_within,
#     left = TRUE
#   )
# 
# # Count restaurants by Yelp city and geographic place
# restaurants_with_place |>
#   st_drop_geometry() |>
#   count(place_name, sort = TRUE)
# 
# # Graphing
# new_orleans_boundary <- louisiana_places |>
#   filter(NAME == "New Orleans")
# 
# 
# ggplot() +
#   geom_sf(data = new_orleans_boundary, fill = "grey95", color = "grey35") +
#   geom_sf(
#     data = restaurants_with_place,
#     aes(color = review_count),
#     alpha = 0.65,
#     size = 1
#   ) +
#   scale_color_viridis_c(option = "C", limits = c(1, 5)) +
#   labs(
#     title = "Yelp Restaurants Located Within New Orleans",
#   ) +
#   theme_minimal()


# Geography analysis ===========================================================

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

map_restaurants <- function(
    restaurants,
    boundaries,
    area_col,
    area_id,
    map_title = "Yelp Restaurants by Geographic Area",
    min_restaurants = 5
) {
  
  # 1. Convert restaurant coordinates into spatial points
  restaurant_points <- restaurants |>
    filter(!is.na(longitude), !is.na(latitude)) |>
    st_as_sf(
      coords = c("longitude", "latitude"),
      crs = 4326,
      remove = FALSE
    )
  
  # 2. Transform geo boundaries to match restaurant CRS
  boundaries <- boundaries |>
    st_transform(st_crs(restaurant_points)) |>
    rename(
      area_id = {{ area_id }},
      area_name = {{ area_col }}
    )
  
  
  # 3. Spatially join restaurants with geographic areas
  restaurants_with_area <- restaurant_points |>
    st_join(
      boundaries |>
        select(area_id, area_name),
      join = st_within,
      left = TRUE
    )
  
  
  # 4. Count restaurants and calculate ratings by geographic area
  area_summary <- restaurants_with_area |>
    st_drop_geometry() |>
    filter(!is.na(area_id)) |>
    group_by(area_id, area_name) |>
    summarise(
      n_restaurants = n_distinct(business_id),
      
      avg_rating = if (all(is.na(stars))) {
        NA_real_
      } else {
        mean(stars, na.rm = TRUE)
      },
      
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
  
  # Include geographic areas with zero restaurants
  area_summary <- boundaries |>
    st_drop_geometry() |>
    select(area_id, area_name) |>
    left_join(
      area_summary,
      by = c("area_id", "area_name")
    ) |>
    mutate(
      n_restaurants = replace_na(n_restaurants, 0L)
    )
  
  
  # 5. Evaluate geographic coverage
  total_restaurants <- n_distinct(restaurants$business_id)
  
  missing_coords <- total_restaurants -
    n_distinct(restaurant_points$business_id)
  
  coverage <- restaurants_with_area |>
    st_drop_geometry() |>
    summarise(
      matched = n_distinct(
        business_id[!is.na(area_id)]
      ),
      unmatched = n_distinct(
        business_id[is.na(area_id)]
      )
    ) |>
    mutate(
      total_restaurants = total_restaurants,
      missing_coordinates = missing_coords,
      match_rate = round(
        100 * matched / total_restaurants,
        2
      )
    )
  
  
  # 6. Evaluate sample size by area
  sample_size <- area_summary |>
    summarise(
      total_areas = n(),
      empty_areas = sum(n_restaurants == 0),
      sparse_areas = sum(
        n_restaurants > 0 &
          n_restaurants < min_restaurants
      ),
      median_restaurants = median(n_restaurants),
      mean_restaurants = mean(n_restaurants),
      min_restaurants = min(n_restaurants),
      max_restaurants = max(n_restaurants)
    )
  
  # Identify areas with few restaurants
  sparse_areas <- area_summary |>
    filter(
      n_restaurants > 0,
      n_restaurants < min_restaurants
    ) |>
    arrange(n_restaurants)
  
  
  # 7. Join summary statistics back to boundaries
  boundary_summary <- boundaries |>
    left_join(
      area_summary |>
        select(
          area_id,
          n_restaurants,
          avg_rating,
          weighted_rating
        ),
      by = "area_id"
    )
  
  
  # 8a. Restaurant location map
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
  
  
  # 8b. Restaurant count map
  count_map <- ggplot(boundary_summary) +
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
  
  
  # 8c. Average rating map
  rating_map <- ggplot(boundary_summary) +
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
  
  
  # 9. Return results
  list(
    restaurants = restaurants_with_area,
    summary = area_summary,
    coverage = coverage,
    sample_size = sample_size,
    sparse_areas = sparse_areas,
    boundaries = boundary_summary,
    location_map = location_map,
    count_map = count_map,
    rating_map = rating_map
  )
}


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

# Counts
tracts_result$summary |>
  filter(n_restaurants > 2)

neighborhood_result$summary |>
  filter(n_restaurants > 2)

zip_result$summary |>
  filter(n_restaurants > 2)


# Maps
tracts_result$location_map
tracts_result$count_map