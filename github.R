#-------------------------------------------------------------------------------
# get github connection
#-------------------------------------------------------------------------------

readr::read_csv(
  list.files('C:/Users/jmdud/Documents (local)', pattern = 'git', full.names = TRUE)
) |>
  dplyr::pull(RStudio) |>
  credentials::set_github_pat()

usethis::git_sitrep()

#-------------------------------------------------------------------------------
