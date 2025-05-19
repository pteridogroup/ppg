source("R/packages.R")
source("R/functions.R")

# Need to increase download timeout for WFO data
timeout_old <- getOption("timeout")
options(timeout = 1200)
on.exit({
  timeout = timeout_old
})

tar_plan(
  # Download WFO backbone exported from Rhakhis
  tar_download(
    wfo_backbone_zip,
    urls = "https://list.worldfloraonline.org/rhakhis/api/downloads/dwc/_uber.zip", # nolint
    paths = "_targets/user/_uber.zip"
  ),
  # Load and clean PPG data ----
  ppg_raw = load_ppg_from_wfo(wfo_backbone_zip),
  ppg = clean_ppg(ppg_raw),
  # Make family-level tree ---
  phy_family = make_family_tree(),
  # Get families in 'phylogenetic' order
  families_in_phy_order = get_ladderized_tips(phy_family),

  # Format data ----
  # - convert DarwinCore format to dataframe in taxonomic order for printing
  #   (only includes accepted taxa at genus and higher)
  ppg_taxdf = dwc_to_taxdf(ppg, families_in_phy_order),

  # Output data files ----
  # - Taxonomic treatment (markdown)
  tar_quarto(
    ppg_md,
    "ppg.Qmd",
    quiet = FALSE
  ),
  tar_file(
    ppg_csv,
    write_csv_tar(ppg, "data/ppg.csv")
  ),
  # Commit and push ppg_md and ppg_csv if modified
  ppg_data_status = check_git_status(c(ppg_md, ppg_csv)),
  last_commit = commit_and_push(ppg_data_status$modified_files)
)
