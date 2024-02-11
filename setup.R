#-------------------------------------------------------------------------------
#' arrow-workshop
#' setup.R
#' https://posit-conf-2023.github.io/arrow/
#-------------------------------------------------------------------------------

# load packages  ----------------------------------------------------------

library(here)
library(arrow)
library(dplyr)
library(duckdb)
library(dbplyr)
library(stringr)
library(lubridate)
library(tictoc)
library(ggplot2)
library(ggrepel)
library(sf)
library(scales)
library(janitor)
library(arrow)
library(dplyr)

# download data -----------------------------------------------------------

data_path <- here::here("arrow-workshop/data/nyc-taxi")

open_dataset("s3://voltrondata-labs-datasets/nyc-taxi") |>
  filter(year %in% 2012:2021) |>
  write_dataset(data_path, partitioning = c("year", "month"))

open_dataset(data_path) |>
  nrow()

options(timeout = 3600)
download.file(
  url = "https://r4ds.s3.us-west-2.amazonaws.com/seattle-library-checkouts.csv",
  destfile = here::here("data/seattle-library-checkouts.csv")
)

options(timeout = 1800)
download.file(
  url = "https://github.com/posit-conf-2023/arrow/releases/download/v0.1.0/taxi_zone_lookup.csv",
  destfile = here::here("data/taxi_zone_lookup.csv")
)

download.file(
  url = "https://github.com/posit-conf-2023/arrow/releases/download/v0.1.0/taxi_zones.zip",
  destfile = here::here("data/taxi_zones.zip")
)

# Extract the spatial files from the zip folder:
unzip(
  zipfile = here::here("arrow-workshop/data/taxi_zones.zip"),
  exdir = here::here("arrow-workshop/data/taxi_zones")
)

#-------------------------------------------------------------------------------

