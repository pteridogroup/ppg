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
  tar_quarto(
    wf_report,
    "R/ppg.Qmd",
    quiet = FALSE
  )
)
