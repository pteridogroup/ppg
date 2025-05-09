# List fern families in rhakhis downloads
# DEPRECATED
get_wfo_zip_files <- function(pattern) {
  url <- "https://list.worldfloraonline.org/rhakhis/api/downloads/dwc/"
  page <- rvest::read_html(url)

  # Extract all links from the page
  links_all <- page |>
    rvest::html_elements("a") |>
    rvest::html_attr("href")

  links <- links_all[grepl(
    pattern,
    links_all
  )]

  # Filter for links ending with ".zip"
  zip_links <- links[grepl("\\.zip$", links)]

  # Convert relative links to absolute URLs if necessary
  zip_urls <- ifelse(
    grepl("^http", zip_links),
    zip_links,
    paste0(url, zip_links)
  )
  zip_urls
}

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
  #  Related to Thelypteridoideae, should be fixed when that comes through
  keep_list <- c(
    "wfo-4100004576",
    "wfo-4100004576",
    "wfo-7000000055",
    "wfo-7000000174",
    "wfo-6500000507",
    "wfo-7000000341",
    "wfo-7000000433",
    "wfo-6500000523",
    "wfo-7000000055",
    "wfo-7000000433",
    "wfo-4100004576",
    "wfo-4100004576",
    "wfo-4100004576",
    "wfo-6500000522"
  )

  ppg_raw |>
    # Exclude those not to process
    # assert(in_set(c(0,1)), doNotProcess) |>
    # filter(doNotProcess == 0) |>
    mutate(
      keep = case_when(
        # Exclude duplicates except those in keep list
        str_detect(doNotProcess_reason, "Duplicate") ~ FALSE,
        taxonID %in% keep_list ~ TRUE,
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

# Helper function for join_higher_taxa()
get_tax <- function(tax, level, highest = FALSE) {
  if (!highest) {
    str_match(tax, paste0("\\b", level, "\\b ([^ ]+) ")) |>
      magrittr::extract(, 2)
  } else {
    str_match(tax, paste0("\\b", level, "\\b ([^ ]+)")) |>
      magrittr::extract(, 2)
  }
}

# Helper function for join_higher_taxa()
tax_to_col_single <- function(tax) {
  subtribe <- get_tax(tax, "subtribe")
  tribe <- get_tax(tax, "tribe")
  subfamily <- get_tax(tax, "subfamily")
  family <- get_tax(tax, "family")
  suborder <- get_tax(tax, "suborder")
  order <- get_tax(tax, "order")
  subclass <- get_tax(tax, "subclass")
  class <- get_tax(tax, "class", highest = TRUE)
  tibble(
    subtribe = subtribe,
    tribe = tribe,
    subfamily = subfamily,
    family = family,
    suborder = suborder,
    order = order,
    subclass = subclass,
    class = class
  )
}

# Helper function for join_higher_taxa()
add_parent_info <- function(df, parent_df, number) {
  parent_name_col <- sym(glue::glue("parent_{number}_name"))
  parent_rank_col <- sym(glue::glue("parent_{number}_rank"))
  highest_parent_name_col <- sym(glue::glue("parent_{number - 1}_name"))

  df %>%
    left_join(
      unique(select(
        parent_df,
        scientificName,
        !!parent_rank_col := parentNameRank,
        !!parent_name_col := parentNameUsage
      )),
      by = setNames("scientificName", as.character(highest_parent_name_col))
    )
}

# Helper function for join_higher_taxa()
tax_to_col <- function(taxonomy) {
  map_df(taxonomy, tax_to_col_single)
}

# Join higher taxa (genus, tribe, subfamily, family, order) to PPG dataframe
widen_dwct <- function(ppg) {
  # Prepare initial dataframe for joining parent taxa
  # Adds non-DWC 'parentNameRank' column
  wf_dwc_p <- ppg |>
    filter(taxonomicStatus == "accepted") |>
    dwctaxon::dct_fill_col(
      fill_to = "parentNameUsage",
      fill_from = "scientificName",
      match_to = "taxonID",
      match_from = "parentNameUsageID"
    ) |>
    dplyr::select(
      taxonID,
      scientificName,
      taxonRank,
      parentNameUsage
    )

  wf_dwc_p <-
    wf_dwc_p %>%
    left_join(
      unique(select(wf_dwc_p, scientificName, parentNameRank = taxonRank)),
      join_by(parentNameUsage == scientificName),
      relationship = "many-to-one"
    ) |>
    assertr::assert(not_na, taxonID) |>
    assertr::assert(is_uniq, taxonID)

  wf_dwc_p %>%
    # progressively map on higher taxa
    rename(parent_1_name = parentNameUsage, parent_1_rank = parentNameRank) %>%
    relocate(parent_1_rank, .before = parent_1_name) |>
    add_parent_info(wf_dwc_p, 2) %>%
    add_parent_info(wf_dwc_p, 3) %>%
    add_parent_info(wf_dwc_p, 4) %>%
    add_parent_info(wf_dwc_p, 5) %>%
    add_parent_info(wf_dwc_p, 6) %>%
    add_parent_info(wf_dwc_p, 7) %>%
    # done when there are no more names to add
    # for species, should be done after adding 7 levels.
    # for genus, should be done after adding 6 levels.
    # confirm that next level doesn't add new information.
    verify(!all(is.na(parent_6_name))) %>%
    verify(all(is.na(parent_7_name))) %>%
    select(-contains("_7_")) |>
    select(-taxonID) |>
    unite("taxonomy", matches("_name|_rank"), sep = " ") |>
    select(scientificName, taxonomy) |>
    mutate(taxonomy_df = tax_to_col(taxonomy)) |>
    select(-taxonomy) %>%
    unnest(cols = taxonomy_df)
}
