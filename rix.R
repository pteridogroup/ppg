# Need this for authentication via rix when using gitcreds
# https://docs.ropensci.org/rix/articles/z-advanced-topic-handling-packages-with-remote-dependencies.html#authenticating-to-github # nolint
my_token <- gitcreds::gitcreds_get()$password
Sys.setenv(GITHUB_PAT = my_token)

# Automatically list all packages used
proj_pkgs_df <- renv::dependencies()

# Manually specify packages from GitHub
proj_git_pkgs <- list(
  ftolr = list(
    package_name = "ftolr",
    repo_url = "https://github.com/fernphy/ftolr",
    commit = "e6f8e9b2273b3c205562b30cc769045f64113b71"
  )
)

# Exclude GitHub packages from other project packages
# add languageserver for VS code
proj_pkgs <- proj_pkgs_df$Package |>
  c("languageserver") |>
  unique() |>
  sort()
proj_pkgs <- proj_pkgs[proj_pkgs != names(proj_git_pkgs)]

# Snapshot rix environment
rix::rix(
  r_ver = "4.5.0",
  r_pkgs = proj_pkgs,
  system_pkgs = NULL,
  git_pkgs = proj_git_pkgs,
  ide = "none",
  project_path = ".",
  overwrite = TRUE
)
