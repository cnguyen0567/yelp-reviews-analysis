source("scripts/config.R")

## Constants ===================================================================
min_reviewer_reviews     <- 5                 # main lifetime-review threshold for "eligible" reviewers
threshold_options        <- c(1, 5, 10, 20, 50, 100)  # thresholds for sensitivity checks
min_restaurant_reviews   <- 10                 # min reviews (all reviewers) to rank a restaurant
min_eligible_reviews     <- 5                  # min eligible-reviewer reviews to rank a restaurant (adjusted)
min_restaurants_per_area <- 5                  # min restaurants for a ZIP to be ranked



# Function to filter reviewers with at least k lifetime Yelp reviews
select_reviewers <- function(users, k) {
  users |> filter(lifetime_reviews >= k)
}

# Function to create restaurant-level adjusted ratings using only reviewers with >= k lifetime reviews.
adjusted_summary <- function(reviews_adjusted, k,
                             users = selected_users_data,
                             score_col = normalized_mean_score) {
  reviews_adjusted |>
    semi_join(select_reviewers(users, k), by = "user_id") |>
    group_by(business_id) |>
    summarise(
      n_reviews_eligible   = n(),
      n_reviewers_eligible = n_distinct(user_id),
      mean_stars_eligible  = mean(stars, na.rm = TRUE),
      mean_normalized      = mean({{ score_col }}, na.rm = TRUE),
      .groups = "drop"
    )
}


## Load data ===================================================================
selected_business_data <- readRDS(business_selected_rds)

selected_reviews_data <- readRDS(review_filtered_rds) |>
  semi_join(selected_business_data, by = "business_id") |>
  mutate(
    review_date = as_date(date),     # handles "YYYY-MM-DD" and "YYYY-MM-DD HH:MM:SS"
    review_year = year(review_date)
  )

selected_users_data <- readRDS(user_filtered_rds) |>
  semi_join(selected_reviews_data, by = "user_id") |>
  select(user_id,
         lifetime_reviews  = review_count,
         lifetime_avg_star = average_stars,
         yelping_since)


# A. All reviewers: restaurant-level ratings ===================================
all_reviewer_summary <- selected_reviews_data |>
  group_by(business_id) |>
  summarise(
    n_reviews_all    = n(),
    n_reviewers_all  = n_distinct(user_id),
    mean_stars_all   = mean(stars, na.rm = TRUE),
    median_stars_all = median(stars, na.rm = TRUE),
    .groups = "drop"
  )


# B. Reviewer activity and threshold sensitivity ===============================
# selecting eligible reviewers
eligible_reviewers <- select_reviewers(selected_users_data, min_reviewer_reviews)

#filer reviews to just from eligible reviewers
selected_reviewer_reviews <- selected_reviews_data |>
  semi_join(eligible_reviewers, by = "user_id")

# how many reviewers / category reviews survive the rule
reviewer_retention <- tibble(
  group     = c("All reviewers", "Eligible reviewers"),
  reviewers = c(n_distinct(selected_reviews_data$user_id),
                n_distinct(selected_reviewer_reviews$user_id)),
  reviews   = c(nrow(selected_reviews_data),
                nrow(selected_reviewer_reviews))
) |>
  mutate(
    pct_reviewers = reviewers / first(reviewers),
    pct_reviews   = reviews / first(reviews)
  )


# How results depend on the lifetime-review threshold
threshold_sensitivity <- map_dfr(threshold_options, \(k) {
  ids  <- select_reviewers(selected_users_data, k)$user_id
  keep <- selected_reviews_data$user_id %in% ids
  tibble(
    min_lifetime_reviews = k,
    reviewers_retained   = length(ids),
    pct_reviewers        = length(ids) / n_distinct(selected_reviews_data$user_id),
    reviews_retained     = sum(keep),
    pct_reviews          = reviews_retained / nrow(selected_reviews_data),
    restaurants_covered  = n_distinct(selected_reviews_data$business_id[keep])
  )
})


# C. Normalize each reviewer's scores ==========================================
# Each reviewer's baseline within the selected categories
reviewer_baselines <- selected_reviews_data |>
  group_by(user_id) |>
  summarise(
    reviewer_mean         = mean(stars, na.rm = TRUE),
    reviewer_median       = median(stars, na.rm = TRUE),
    reviewer_review_count = n(),
    .groups = "drop"
  )

# Attach baselines to each review and compute normalized scores
selected_reviews_adjusted <- selected_reviews_data |>
  left_join(reviewer_baselines, by = "user_id") |>
  left_join(selected_users_data |> select(user_id, lifetime_avg_star), by = "user_id") |>
  mutate(
    normalized_mean_score     = stars - reviewer_mean,
    normalized_median_score   = stars - reviewer_median,
    normalized_lifetime_score = stars - lifetime_avg_star
  )

# Keep only eligible reviewers
eligible_adjusted_reviews <- selected_reviews_adjusted |>
  semi_join(eligible_reviewers, by = "user_id")

# Reviewers with only one category review always get normalized_mean_score = 0
eligible_adjusted_reviews |>
  distinct(user_id, reviewer_review_count) |>
  count(only_one_category_review = reviewer_review_count == 1)


# D. Restaurant-level table: all reviewers vs. eligible reviewers ==============
restaurant_ratings <- selected_business_data |>
  select(business_id, business_name, area_id, area_name,
         yelp_stars = stars, yelp_review_count = review_count,
         latitude, longitude) |>
  left_join(all_reviewer_summary, by = "business_id") |>
  # must use the *adjusted* reviews (they hold the normalized scores)
  left_join(adjusted_summary(selected_reviews_adjusted, min_reviewer_reviews),
            by = "business_id") |>
  mutate(
    rank_all = min_rank(desc(if_else(
      coalesce(n_reviews_all, 0L) >= min_restaurant_reviews, mean_stars_all, NA_real_))),
    rank_adjusted = min_rank(desc(if_else(
      coalesce(n_reviews_eligible, 0L) >= min_eligible_reviews, mean_normalized, NA_real_))),
    rank_change = rank_all - rank_adjusted     # positive = moved up after adjustment
  )

top10_all <- restaurant_ratings |>
  filter(!is.na(rank_all)) |>
  arrange(rank_all) |>
  slice_head(n = 10)

top10_adjusted <- restaurant_ratings |>
  filter(!is.na(rank_adjusted)) |>
  arrange(rank_adjusted) |>
  slice_head(n = 10)

biggest_rank_changes <- restaurant_ratings |>
  filter(!is.na(rank_all), !is.na(rank_adjusted)) |>
  arrange(desc(abs(rank_change))) |>
  slice_head(n = 10) |>
  select(business_name, area_name, n_reviews_all, mean_stars_all,
         n_reviews_eligible, mean_normalized, rank_all, rank_adjusted, rank_change)


# E. Does the threshold change the adjusted top 10? ============================
top10_by_threshold <- map_dfr(threshold_options, \(k) {
  adjusted_summary(selected_reviews_adjusted, k) |>
    filter(n_reviews_eligible >= min_eligible_reviews) |>
    slice_max(mean_normalized, n = 10, with_ties = FALSE) |>
    mutate(min_lifetime_reviews = k)
})

threshold_overlap <- top10_by_threshold |>
  group_by(min_lifetime_reviews) |>
  summarise(
    n_ranked = n(),
    overlap_with_main_top10 = sum(business_id %in% top10_adjusted$business_id),
    .groups = "drop"
  )


# F. ZIP-level comparison ======================================================
# Each restaurant counts once (mean of restaurant means).
zip_ratings <- restaurant_ratings |>
  filter(!is.na(area_id)) |>
  group_by(area_id, area_name) |>
  summarise(
    n_restaurants          = n(),
    n_reviews_all          = sum(n_reviews_all, na.rm = TRUE),
    mean_stars_all         = mean(mean_stars_all, na.rm = TRUE),
    n_restaurants_adjusted = sum(!is.na(mean_normalized)),
    n_reviews_eligible     = sum(n_reviews_eligible, na.rm = TRUE),
    mean_normalized        = mean(mean_normalized, na.rm = TRUE),
    n_top10_adjusted       = sum(business_id %in% top10_adjusted$business_id),
    .groups = "drop"
  ) |>
  mutate(
    across(c(mean_stars_all, mean_normalized), \(x) if_else(is.nan(x), NA_real_, x)),
    rankable        = n_restaurants >= min_restaurants_per_area,
    rank_all        = min_rank(desc(if_else(rankable, mean_stars_all, NA_real_))),
    rank_adjusted   = min_rank(desc(if_else(rankable, mean_normalized, NA_real_))),
    rank_change     = rank_all - rank_adjusted
  ) |>
  arrange(rank_adjusted)


# Results ======================================================================
# A
all_reviewer_summary |>
  left_join(selected_business_data |> select(business_id, business_name),  #add business name for revew
            by = "business_id") |>
  arrange(desc(n_reviews_all)) |>
  slice_head(n = 30)

# B
reviewer_retention
threshold_sensitivity

#C
top10_by_threshold
threshold_overlap
top10_all
top10_adjusted
biggest_rank_changes

zip_ratings


# Note: creating business_selected_rds =========================================
# Add to config.R:
#   business_selected_rds <- "data/new_orleans/business_selected_new_orleans.rds"
# Add to the end of geography_analysis.R:
#   saveRDS(sf::st_drop_geometry(zip_result$restaurants), business_selected_rds, compress = "xz")
