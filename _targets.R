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
  tar_file_read(
    ppgi_supp_data_raw,
    "_targets/user/ppgi_data.xlsx",
    readxl::read_xlsx(!!.x)
  ),
  # - original supplemental data from PPG I
  ppgi_supp_data = clean_ppgi_supp_data(ppgi_supp_data_raw),
  # - template of supplemental data for PPG II and onwards
  ppgii_supp_data_template = make_initial_ppgii_supp_data(
    ppgi_supp_data,
    ppg_taxdf
  ),
  # - read in data from manually filled templae
  tar_file_read(
    ppg_supp_data,
    "_targets/user/ppg_supp_data.csv",
    readr::read_csv(!!.x)
  ),
  # Make family-level tree ---
  phy_family = make_family_tree(),
  # Get families in 'phylogenetic' order
  families_in_phy_order = get_ladderized_tips(phy_family),

  # Format data ----
  # - convert DarwinCore format to dataframe in taxonomic order for printing
  #   (only includes accepted taxa at genus and higher)
  ppg_tl = dwc_to_tl(ppg, families_in_phy_order),

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
