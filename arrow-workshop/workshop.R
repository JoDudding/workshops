#-------------------------------------------------------------------------------
#' arrow-workshop
#' workshop.R
#' https://posit-conf-2023.github.io/arrow/
#-------------------------------------------------------------------------------

library(arrow)
library(tictoc)
library(dplyr)
library(cli)
library(duckdb)

nyc_taxi <- open_dataset(here::here("data/nyc-taxi"))

nrow(nyc_taxi)

glimpse(nyc_taxi)

# hello arrow -------------------------------------------------------------
# Calculate the longest trip distance for every month in 2019
# How long did this query take to run?

tic()
nyc_taxi |>
  filter(year == 2019) |>
  group_by(month) |>
  summarise(longest = max(trip_distance)) |>
  collect() |>
  arrange(-longest)
toc()

# manipulating data with arrow (part 1) -----------------------------------
# How many taxi fares in the dataset had a total amount greater than $100?

nyc_taxi |>
  filter(total_amount > 100) |>
  count(year) |>
  collect() |>
  summarise(n = sum(n))

# How many distinct pickup locations (distinct combinations of the
# pickup_latitude and pickup_longitude columns) are in the dataset since
# 2016?

nyc_taxi |>
  filter(year == 2016) |>
  distinct(pickup_latitude, pickup_longitude) |>
  compute() |>
  nrow()

# Use the dplyr::filter() and stringr::str_ends() functions to return a
# subset of the data which is a) from September 2020, and b) the value in
# vendor_name ends with the letter “S”.

nyc_taxi |>
  filter(
    year == 2020,
    month == 9,
    stringr::str_ends(vendor_name, 'S')
  ) |>
  collect()


# Try to use the stringr function str_replace_na() to replace any NA
# values in the vendor_name column with the string “No vendor” instead.
# What happens, and why?

nyc_taxi |>
  mutate(vendor_name = stringr::str_replace_na(vendor_name, 'No vendor'))

# Bonus question: see if you can find a different way of completing the
# task in question 2.

nyc_taxi |>
  mutate(vendor_name = coalesce(vendor_name, 'No vendor')) |>
  count(vendor_name) |>
  collect()

# data engineering with arrow ---------------------------------------------
#' The first few thousand rows of ISBN are blank in the Seattle Checkouts CSV
#' file. Read in the Seattle Checkouts CSV file with open_dataset() and ensure
#' the correct data type for ISBN is <string> instead of the <null> interpreted
#' by Arrow.

seattle_csv <- open_dataset(
  sources = here::here("data/seattle-library-checkouts.csv"),
  format = "csv",
  skip = 1,
  schema = schema(
    UsageClass = utf8(),
    CheckoutType = utf8(),
    MaterialType = utf8(),
    CheckoutYear = int64(),
    CheckoutMonth = int64(),
    Checkouts = int64(),
    Title = utf8(),
    ISBN = string(), #utf8()
    Creator = utf8(),
    Subjects = utf8(),
    Publisher = utf8(),
    PublicationYear = utf8()
  )
)

seattle_csv

schema(seattle_csv)

# get the schema as code that can be edited and put into the open_dataset
seattle_csv$schema$code()

#' Once you have a Dataset object with the metadata you are after, count the
#' number of Checkouts by CheckoutYear and arrange the result by CheckoutYear.

tic()
seattle_csv |>
  count(CheckoutYear, wt = Checkouts) |>
  arrange(CheckoutYear) |>
  collect()
toc()

#' Re-run the query counting the number of Checkouts by CheckoutYear and
#' arranging the result by CheckoutYear, this time using the Seattle Checkout
#' data saved to disk as a single, Parquet file. Did you notice a difference in
#' compute time?

seattle_parquet <- here::here("data/seattle-library-checkouts-parquet")

seattle_csv |>
  write_dataset(path = seattle_parquet, format = "parquet")

file <- list.files(seattle_parquet)
file.size(file.path(seattle_parquet, file)) / 10**9


seattle_pq <- open_dataset(seattle_parquet)

tic()
seattle_pq |>
  count(CheckoutYear, wt = Checkouts) |>
  arrange(CheckoutYear) |>
  collect()
toc()

#' Let’s write the Seattle Checkout CSV data to a multi-file dataset just one
#' more time! This time, write the data partitioned by CheckoutType as Parquet
#' files.

seattle_parquet_part <- here::here("data/seattle-library-checkouts")

seattle_csv |>
  group_by(CheckoutType) |>
  write_dataset(path = seattle_parquet_part, format = "parquet")


sizes <- tibble(
  files = list.files(seattle_parquet_part, recursive = TRUE),
  size_GB = file.size(file.path(seattle_parquet_part, files)) / 10**9
)

sizes

#' Now compare the compute time between our Parquet data partitioned by
#' CheckoutYear and our Parquet data partitioned by CheckoutType with a query
#' of the total number of checkouts in September of 2019. Did you find a
#' difference in compute time?

seattle_pq_part <- open_dataset(seattle_parquet_part)

tic()
seattle_pq_part |>
  count(CheckoutYear, wt = Checkouts) |>
  arrange(CheckoutYear) |>
  collect()
toc()


# in-memory workflows -----------------------------------------------------
#' Read in a single NYC Taxi parquet file using read_parquet() as an Arrow Table

taxi_single <- read_parquet(
  "data/nyc-taxi/year=2019/month=9/part-0.parquet",
  as_data_frame = FALSE
)


#' Convert your Arrow Table object to a data.frame or a tibble

taxi_single_tbl <- taxi_single |>
  collect()

# manipulating data with arrow (part 2) -----------------------------------
#' Write a user-defined function which wraps the stringr function
#' str_replace_na(), and use it to replace any NA values in the vendor_name
#' column with the string “No vendor” instead. (Test it on the data from 2019
#' so you’re not pulling everything into memory)

register_scalar_function(
  name = "replace_vendor_na",
  function(context, string) {
    str_replace_na(string, "No vendor")
  },
  in_type = schema(
    string = string()
  ),
  out_type = string(),
  auto_convert = TRUE
)

nyc_taxi_2019_vendor <- nyc_taxi |>
  filter(year == 2019) |>
  distinct(vendor_name) |>
  compute()

nyc_taxi_2019_vendor |>
  mutate(vendor_name = replace_vendor_na(vendor_name)) |>
  collect()



vendors <- tibble::tibble(
  code = c("VTS", "CMT", "DDS"),
  full_name = c(
    "Verifone Transportation Systems",
    "Creative Mobile Technologies",
    "Digital Dispatch Systems"
  )
)

nyc_taxi |>
  left_join(vendors, by = c("vendor_name" = "code")) |>
  select(vendor_name, full_name, pickup_datetime) |>
  head(3) |>
  collect()




#' How many taxi pickups were recorded in 2019 from the three major airports
#' covered by the NYC Taxis data set (JFK, LaGuardia, Newark)? (Hint: you can
#' use stringr::str_detect() to help you find pickup zones with the word
#' “Airport” in them)

nyc_taxi_zones <- read_csv_arrow(here::here("data/taxi_zone_lookup.csv")) |>
  select(location_id = LocationID, borough = Borough, zone = Zone)

nyc_taxi_zones_arrow <- arrow_table(
  nyc_taxi_zones,
  schema = schema(location_id = int64(), borough = utf8(), zone = utf8())
)

pickup_airport <- nyc_taxi_zones_arrow |>
  filter(str_detect(str_to_lower(zone), 'airport')) |>
  select(
    pickup_location_id = location_id, pickup_borough = borough,
    pickup_zone = zone
  )

nyc_taxi |>
  filter(year == 2019) |>
  inner_join(pickup_airport) |>
  count(pickup_zone) |>
  arrange(-n) |>
  collect()

#' How many trips in September 2019 had a longer than average distance for that
#' month?

nyc_taxi |>
  filter(year == 2019, month == 9) |>
  to_duckdb() |>
  mutate(mean_distance = mean(trip_distance, na.rm = TRUE)) |>
  to_arrow() |>
  filter(trip_distance > mean_distance) |>
  count() |>
  collect()


# spatial -----------------------------------------------------------------

library(sf)
library(ggplot2)
library(ggrepel)
library(stringr)
library(scales)
library(arrow)
library(dplyr)
library(janitor)
library(stringr)

nyc_taxi_zones <- read_csv_arrow(
  here::here("data/taxi_zone_lookup.csv"),as_data_frame = FALSE
) |>
  clean_names()

airport_zones <- nyc_taxi_zones |>
  filter(str_detect(zone, "Airport")) |>
  pull(location_id, as_vector = TRUE)

dropoff_zones <- nyc_taxi_zones |>
  select(dropoff_location_id = location_id, dropoff_zone = zone) |>
  compute()

airport_pickups <- open_dataset(here::here("data/nyc-taxi")) |>
  filter(pickup_location_id %in% airport_zones) |>
  select(
    matches("datetime"),
    matches("location_id")
  ) |>
  left_join(dropoff_zones) |>
  count(dropoff_zone) |>
  arrange(desc(n)) |>
  collect()

map <- read_sf(here::here("data/taxi_zones/taxi_zones.shp")) |>
  clean_names() |>
  left_join(airport_pickups, by = c("zone" = "dropoff_zone")) |>
  arrange(desc(n))

arrow_r_together <- ggplot(data = map, aes(fill = n)) +
  geom_sf(size = .1) +
  scale_fill_distiller(
    name = "Number of trips",
    labels = label_comma(),
    palette = "Reds",
    direction = 1
  ) +
  geom_label_repel(
    stat = "sf_coordinates",
    data = map |>
      mutate(zone_label = case_when(
        str_detect(zone, "Airport") ~ zone,
        str_detect(zone, "Times") ~ zone,
        .default = ""
      )),
    mapping = aes(label = zone_label, geometry = geometry),
    max.overlaps = 60,
    label.padding = .3,
    fill = "white"
  ) +
  theme_void()


arrow_r_together

#-------------------------------------------------------------------------------
