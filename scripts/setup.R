# Install package ==============================================================
required_packages <- c(
  "tidyverse",
  "jsonlite",
  "lubridate",
  "sf",
  "tigris",
  "scales",
  "viridis"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(
      pkg,
      repos = "https://cloud.r-project.org"
    )
  }
}