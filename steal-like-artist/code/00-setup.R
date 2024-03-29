################################################################################
#                                                                              #
#                   Steal like an Rtist: Creative Coding in R                  #
#                                                                              #
#                                    Setup                                     #
#                                                                              #
#                 Ijeamaka Anyene Fumagalli and Sharla Gelfand                 #
#                              posit::conf(2023)                               #
#                              September 18, 2023                              #
#                                                                              #
################################################################################


# Install packages -------------------------------------------------------------

packages <- c("dplyr", "ggforce", "ggplot2", "glue", "knitr", "magick",
  "prismatic", "plotwidgets", "purrr", "rmarkdown", "scales", "tidyr", "usethis")

install.packages(setdiff(packages, rownames(installed.packages())))

# Download workshop materials --------------------------------------------------

library(usethis)

use_course(
  "sharlagelfand/creative-coding-workshop",
  destdir = here::here('steal-like-artist')
)

