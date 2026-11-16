Vegetarian-Friendly Dining in New Orleans -- Steps 1-6 report draft

Files:
  vegetarian_new_orleans_steps1-6.qmd  Editable Quarto report with live R output
  vegetarian_report.css             Styles for Quarto HTML
  vegetarian_new_orleans_steps1-6_preview.html  Narrative-only preview

Instructions:
1. Copy the .qmd and .css files into the root of your Yelp Review Project.
2. Keep the existing scripts/ and data/new_orleans/ folders in that project.
3. Run the report from the project root in RStudio or use:
   quarto render vegetarian_new_orleans_steps1-6.qmd
4. Confirm the R packages used by scripts/config.R are installed.

The Quarto report sources scripts/geography_analysis.R, which sources
scripts/config.R and loads the filtered RDS files. It also downloads or
loads geographic boundary data via tigris and the local neighborhood GeoJSON.

The preview HTML is not a final analytical render: numeric category overlaps,
coverage tables, charts, maps, and the interactive hover tooltips populate only
when Quarto runs the R code with your project data. The narrative-preview values
for selected restaurants come from the preliminary project findings.

To finish before publication:
- Verify the computed counts (notably 1-tag vs. multi-tag categories).
- Document specific first-hand large-data import/storage challenges.
- Verify official place-boundary mismatches and geographic area extents.
- Add the exact URL for the City of New Orleans neighborhood GeoJSON.
- Finish Step 7's reviewer-normalized ratings, top-10 table, and final map.
- Add the generated HTML and source links to GitHub README.
