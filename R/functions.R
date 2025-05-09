#' Load PPG Data from WFO Backbone Zip File
#'
#' This function extracts and processes a Darwin Core (DwC) classification
#' file from a zipped WFO (World Flora Online) backbone file. It filters
#' the data to include only ferns and lycophytes (major groups
#' "Lycopodiophyta" and "Polypodiophyta").
#'
#' @param wfo_backbone_zip A string specifying the path to the WFO backbone
#'   zip file containing the DwC classification file.
#'
#' @return A data frame containing the filtered PPG (Pteridophyte Phylogeny
#'   Group) data.
#'
#' @details The function performs the following steps:
#'   1. Unzips the specified WFO backbone zip file to a temporary directory.
#'   2. Reads the `classification.csv` file from the unzipped contents.
#'   3. Filters the data to include only rows where the `majorGroup` column
#'      is either "Lycopodiophyta" or "Polypodiophyta".
#'   4. Deletes the temporary directory after processing.

load_ppg_from_wfo <- function(wfo_backbone_zip) {
  # Unzip dwc file to temp dir
  unzip_dir <- tempfile()
  dwc_file <- "classification.csv"
  unzip(wfo_backbone_zip, files = dwc_file, exdir = unzip_dir)
  # Read it
  ppg <-
    fs::path(unzip_dir, dwc_file) |>
    readr::read_csv() |>
    dplyr::filter(
      majorGroup == "Lycopodiophyta" | majorGroup == "Polypodiophyta"
    )
  # Delete temp file
  fs::dir_delete(unzip_dir)
  ppg
}

clean_ppg <- function(ppg_raw) {
  ppg_raw |>
    mutate(
      keep = case_when(
        # Exclude duplicates
        str_detect(doNotProcess_reason, "Duplicate") ~ FALSE,
        .default = TRUE
      )
    ) |>
    filter(keep) |>
    # Select cols
    select(
      taxonID,
      scientificName,
      scientificNameAuthorship,
      taxonRank,
      parentNameUsageID,
      nomenclaturalStatus,
      namePublishedIn,
      taxonomicStatus,
      acceptedNameUsageID,
      # Need to check if this is actually the basionym
      # originalNameUsageID,
      taxonRemarks,
      created,
      modified
    ) |>
    # Set class as the highest recognized rank
    filter(!taxonRank %in% c("kingdom", "subkingdom", "phylum")) |>
    mutate(
      parentNameUsageID = case_when(
        taxonRank == "class" ~ NA_character_,
        .default = parentNameUsageID
      ),
      taxonomicStatus = case_when(
        taxonomicStatus == "Accepted" ~ "accepted",
        taxonomicStatus == "Synonym" ~ "synonym",
        taxonomicStatus == "Unchecked" ~ "unchecked",
        .default = taxonomicStatus
      ),
      nomenclaturalStatus = str_to_lower(nomenclaturalStatus)
    ) |>
    # Validate
    dwctaxon::dct_validate(
      valid_tax_status = "accepted, synonym, unchecked, variant",
      extra_cols = "created",
      check_taxon_id = TRUE,
      check_tax_status = TRUE,
      check_mapping_accepted = TRUE,
      check_mapping_parent = TRUE,
      check_mapping_accepted_status = TRUE,

      # Don't check basionyms for now
      check_mapping_original = FALSE,

      # Enable when https://github.com/ropensci/dwctaxon/issues/118 is fixed
      check_sci_name = FALSE,
      check_status_diff = FALSE,

      check_col_names = TRUE
    )
}
