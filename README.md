# Finding the Best Vegetarian-Friendly Dining in New Orleans

*A Yelp Open Dataset portfolio project by Chau Nguyen (R · Quarto · DuckDB · sf)*

**📄 [View the full report](https://github.com/cnguyen0567/yelp-reviews-analysis.git)** (opens the rendered `index.html` in browser; no R needed)

---

## Research question

**Where can a visitor find the best vegetarian-friendly restaurants in New Orleans, and which ZIP code is the best bet for finding them?**

## Executive summary

Yelp Open Dataset was filtered to open New Orleans restaurants tagged *Vegetarian*, *Vegan*, *Falafel*, or *Bagels*. Restaurants were compared and ranked with ZIP-code boundaries. The analysis produces a top-10 restaurant list and maps highlighting the ZIP codes with the best vegetarian-friendly dining options.

## Key findings

1. **Most choices: ZIP 70130** (Partial Central Business District / Lower Garden District / French Quarter) has the most vegetarian-friendly restaurants.
2. **Most top-rated restaurants: ZIP 70119** (Mid-City) has more of the 10 best restaurants, after adjusting for reviewer habits.
3. **Highest average rating: ZIP 70117** (Marigny / Bywater) has the highest average Yelp rating among ZIP codes.

The interactive graphs (with hover details), plus the category, geography, and rating analyses, are in the [full report](https://github.com/cnguyen0567/yelp-reviews-analysis.git).

---

## Viewing the report

This project does **not** use GitHub Pages. To view the rendered report, download and open the [`index.html`](https://github.com/cnguyen0567/yelp-reviews-analysis.git)in any browser. The file is self-contained (all maps, tables, and styles are embedded).

## Files and folders

```
Yelp Review Project/
├── README.md                    # This file
├── index.qmd                    # Quarto source for the report (text + R code)
├── index.html                   # Rendered, self-contained report
├── AI Prompts                   # AI prompts used during the project, with reprompting examples
├── Yelp Review Project.Rproj    # RStudio project file (open this first)
├── .gitignore                   # Keeps raw data and local R session files out of Git
├── data/
│   ├── raw/                     # Raw Yelp JSON files (NOT committed; see below)
│   └── new_orleans/             # Filtered, compressed .rds files used by the report
└── scripts/
    ├── setup.R                  # Installs required R packages
    ├── config.R                 # Libraries, file paths, selected categories, thresholds
    ├── import.R                 # Reads the raw JSON, filters to New Orleans, saves .rds
    ├── categories_analysis.R    # Category counts and co-occurence analysis
    ├── geography_analysis.R     # Spacial join and analysis of ZIP, census tract, and neighborhood boundaries
    └── ratings_analysis.R       # Reviewer eligibility, normalized scores, restaurant and ZIP rankings
```

## Reproducing the project

### 1. Get the code and install packages

1. Clone or download this repository.
2. Open `Yelp Review Project.Rproj` in RStudio.
3. Run `source("scripts/setup.R")` to install the packages.
4. Install [Quarto](https://quarto.org/docs/get-started/) if it isn't already installed with RStudio.

### 2. (Optional) Download the Yelp data

The filtered `.rds` files in `data/new_orleans/` are already in the repository, so the report renders without the raw data. Step is only needed if rebuilding the data from scratch.

1. Download the JSON archive from [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/)
2. Extract and move these three files into `data/raw/`:
   - `yelp_academic_dataset_business.json`
   - `yelp_academic_dataset_review.json`
   - `yelp_academic_dataset_user.json`
3. Run `source("scripts/import.R")`. It streams the business file, then uses DuckDB to read and filter the review and user files in one pass, so only New Orleans records are loaded into memory. The results are saved as `xz`-compressed `.rds` files in `data/new_orleans/`.
4. Can delete the raw JSON once the `.rds` files exist

### 3. (Optional) Run the individual analyses (category, geography, ratings)

### 4. Render the report

From the project root, render on `index.qmd` to get the report. Rendering downloads ZIP and census tract boundaries through `tigris`, so the first run needs an internet connection.

## Why the raw JSON files are not on GitHub

The raw files are far too large for a Git repository: about 100 MB for businesses, 5 GB for reviews, and 3 GB for users. GitHub blocks files over 100 MB, and committing them would make the repository impractical to clone.

`data/raw/` is listed in `.gitignore`. Only the small filtered `.rds` files, which contain just the open New Orleans restaurants and their reviews, are committed.

## Data sources

- **Restaurants and reviews:** [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/)
- **ZIP code (ZCTA) boundaries:** [U.S. Census Bureau](https://www.census.gov/programs-surveys/geography/guidance/geo-areas/zctas.html), 2020, via `tigris::zctas()`
- **Census tract boundaries:** [U.S. Census Bureau](https://www.census.gov/programs-surveys/geography/about/glossary.html#par_textimage_13), 2024, via `tigris::tracts()`
- **Neighborhood Statistical Areas:** [City of New Orleans Open Data](https://data.nola.gov/browse?q=Neighborhood%20Statistical%20Area)

## Notes

- Restaurants are included only if their owners tagged them with one of the four categories on Yelp, so some vegetarian-friendly places are missed. Cusine is also a potential indicator for vegetarian friendly menus, but was not included in this analysis
- The Yelp Open Dataset is a sample, not every New Orleans restaurant, and it is not updated in real time.
- A ZIP code can partially contains and/or split neighborhoods. Overlaying layers may be considered for future analysis.