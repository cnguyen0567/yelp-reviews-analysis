# Install package ==============================================================
required_packages <- c(
  "tidyverse",             #include: dplyr, stringr, ggplot2, tibble, tidyr
  "jsonlite",
  "lubridate",
  "sf",
  "tigris",
  "scales",
  "viridis",
  "patchwork",
  "knitr",
  "DT",
  "ggiraph",
  "DBI",
  "duckdb",
  "ggupset"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(
      pkg,
      repos = "https://cloud.r-project.org"
    )
  }
}
