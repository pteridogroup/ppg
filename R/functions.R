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

#' Clean and Validate PPG Taxonomic Data
#'
#' This function processes raw PPG (Pteridophyte Phylogeny Group) taxonomic
#' data by removing duplicates, selecting relevant columns, standardizing
#' values, and validating the resulting data frame according to Darwin Core
#' standards.
#'
#' @param ppg_raw A data frame containing raw PPG taxonomic data, typically
#'   produced by load_ppg_from_wfo().
#'
#' @return A cleaned and validated data frame of PPG taxonomic records,
#'   suitable for downstream analysis.
#'
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
      # Exclude taxonRemarks from WFO for now, as we can get them from
      # the WFO ID and most are not relevant
      # taxonRemarks,
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

#' Get Ladderized Tip Labels from a Phylogenetic Tree
#'
#' Returns the tip labels of a phylogenetic tree in ladderized order.
#'
#' @param tree A phylogenetic tree object of class phylo.
#'
#' @return A character vector of tip labels in ladderized order.
get_ladderized_tips <- function(tree) {
  is_tip <- tree$edge[, 2] <= length(tree$tip.label)
  ordered_tips <- tree$edge[is_tip, 2]
  tree$tip.label[ordered_tips]
}

#' Make a Family-Level Fern Phylogeny
#'
#' Constructs a family-level phylogenetic tree for ferns using the FTOL
#' backbone and taxonomy, ensuring each family is represented by a single
#' exemplar species and that all families are monophyletic or monotypic.
#'
#' @return A ladderized phylogenetic tree object of class phylo with
#'   family names as tip labels.
make_family_tree <- function() {
  require(ftolr)
  # Load tree
  phy <- ftolr::ft_tree(branch_len = "ultra", rooted = TRUE, drop_og = TRUE)
  # Load fern taxonomy
  taxonomy <- ftol_taxonomy |>
    # Subset to only species in tree
    filter(species %in% phy$tip.label) |>
    select(species, family) |>
    # Make corrections for new families
    mutate(
      family = case_when(
        str_detect(species, "Arthropteris") ~ "Arthropteridaceae",
        str_detect(species, "Draconopteris") ~ "Pteridryaceae",
        str_detect(species, "Malaifilix") ~ "Pteridryaceae",
        str_detect(species, "Polydictyum") ~ "Pteridryaceae",
        str_detect(species, "Pteridrys") ~ "Pteridryaceae",
        .default = family
      )
    )

  # Analyze monophyly of each family
  family_mono_test <- MonoPhy::AssessMonophyly(
    phy,
    as.data.frame(taxonomy[, c("species", "family")])
  )

  # Check that all families are monophyletic or monotypic
  family_mono_summary <-
    family_mono_test$family$result |>
    tibble::rownames_to_column("family") |>
    as_tibble() |>
    assert(in_set("Yes", "Monotypic"), Monophyly)

  # Get one exemplar tip (species) per family
  rep_tips <-
    taxonomy |>
    group_by(family) |>
    slice(1) |>
    ungroup()

  # Subset phylogeny to one tip per family
  phy_family <- ape::keep.tip(phy, rep_tips$species)

  # Relabel with family names
  new_tips <-
    tibble(species = phy_family$tip.label) |>
    left_join(rep_tips, by = "species") |>
    pull(family)

  phy_family$tip.label <- new_tips

  ape::ladderize(phy_family)
}

#' Write a Data Frame to CSV and Return the File Path
#'
#' Writes a data frame to a CSV file and returns the file path.
#'
#' @param x A data frame to write.
#' @param file The file path to write to.
#' @param ... Additional arguments passed to readr::write_csv().
#'
#' @return The file path of the written CSV file.
write_csv_tar <- function(x, file, ...) {
  readr::write_csv(x = x, file = file, ...)
  file
}

#' Check Git Status for Watched Files
#'
#' Checks the git status for a set of watched files, optionally excluding a
#' specific file, and returns the list of modified files and the last commit.
#'
#' @param watched_files A character vector of file paths to watch.
#' @param exclude_file A file to exclude from the check (default: "ppg.Qmd").
#'
#' @return A list with `modified_files` and `last_commit.`
#'
check_git_status <- function(watched_files, exclude_file = "ppg.Qmd") {
  res <- gert::git_status() |>
    filter(file %in% watched_files)

  if (!is.null(exclude_file)) {
    res <- res |>
      filter(file != exclude_file)
  }

  # Return list of modified files and the last commit made
  list(
    modified_files = res |> pull(file),
    last_commit = gert::git_log(max = 1)$commit
  )
}

#' Commit and Push Modified Files to Git
#'
#' Adds, commits, and pushes modified files to the git repository if there are
#' any changes. If no relevant changes are found, returns the last commit.
#'
#' @param modified A character vector of modified file paths.
#'
#' @return The commit hash of the last commit made or found.
#'
commit_and_push <- function(modified) {
  # If there are relevant changes, commit and push
  if (length(modified) > 0) {
    gert::git_add(files = modified)
    last_commit <- gert::git_commit(message = paste("Auto-update:", Sys.time()))
    gert::git_push()
  } else {
    last_commit <- gert::git_log(max = 1)$commit
    message("No relevant changes to commit.")
  }
  last_commit
}

#' Convert Darwin Core Taxonomy to Indented Taxonomic Data Frame
#'
#' Converts a cleaned PPG (Pteridophyte Phylogeny Group) Darwin Core
#' taxonomy data frame to an indented, ordered taxonomic data frame
#' suitable for printing or reporting. The function selects higher
#' taxonomic ranks, orders them according to phylogenetic and
#' classification priorities, and formats the output with markdown-style
#' indentation for each rank.
#'
#' @param ppg A cleaned data frame of PPG taxonomic data, typically the
#'   output of clean_ppg().
#' @param families_in_phy_order A character vector of family names in
#'   phylogenetic order (as returned by make_family_tree()).
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{taxonID}{Unique taxon identifier.}
#'     \item{scientificName}{Scientific name of the taxon.}
#'     \item{scientificNameAuthorship}{Authorship of the scientific name.}
#'     \item{taxonRank}{Taxonomic rank (e.g., family, order).}
#'     \item{indent}{Markdown-style header string for indentation.}
#'   }
dwc_to_tl <- function(ppg, families_in_phy_order) {
  require(taxlist)

  # Specify all higher taxonomic levels
  higher_tax_levels_all <- c(
    "class",
    "subclass",
    "order",
    "suborder",
    "family",
    "subfamily",
    "tribe",
    "subtribe",
    "genus"
  )

  # Format PPG data for printing out
  ppg_print <-
    ppg |>
    # Only keeping higher, accepted taxa
    filter(taxonRank %in% higher_tax_levels_all) |>
    filter(taxonomicStatus == "accepted") |>
    # TODO fix these in Rhakhis
    # Remove bad taxa
    filter(
      taxonID != "wfo-1000070090" # Todea Bernh., PPG I has Todea Willd. ex Bernh.
    )

  # Identify higher taxonomic levels actually used
  higher_tax_levels_used <- higher_tax_levels_all[
    higher_tax_levels_all %in% ppg_print$taxonRank
  ]

  # Set priorities for sorting by rank ----
  # Also check that all names are in data

  # - class
  priority_class <- c(
    "Lycopodiopsida",
    "Polypodiopsida"
  )

  class_check <- ppg_print |>
    filter(taxonRank == "class") |>
    assert(
      in_set(priority_class),
      scientificName,
      success_fun = success_logical
    )

  # - subclass
  priority_subclass <- c(
    "Equisetidae",
    "Ophioglossidae",
    "Marattiidae",
    "Polypodiidae"
  )

  subclass_check <- ppg_print |>
    filter(taxonRank == "subclass") |>
    assert(
      in_set(priority_subclass),
      scientificName,
      success_fun = success_logical
    )

  # - order
  priority_order <- c(
    # (Lycopodiopsida)
    "Lycopodiales",
    "Isoetales",
    "Selaginellales",
    # (Equisetidae)
    "Equisetales",
    # (Ophioglossidae)
    "Psilotales",
    "Ophioglossales",
    # (Marattiidae)
    "Marattiales",
    # (Polypodiidae)
    "Osmundales",
    "Hymenophyllales",
    "Gleicheniales",
    "Schizaeales",
    "Salviniales",
    "Cyatheales",
    "Polypodiales"
  )

  order_check <- ppg_print |>
    filter(taxonRank == "order") |>
    assert(
      in_set(priority_order),
      scientificName,
      success_fun = success_logical
    )

  # suborder
  priority_suborder <- c(
    "Saccolomatineae",
    "Lindsaeineae",
    "Pteridineae",
    "Dennstaedtiineae",
    "Aspleniineae",
    "Polypodiineae"
  )

  suborder_check <- ppg_print |>
    filter(taxonRank == "suborder") |>
    assert(
      in_set(priority_suborder),
      scientificName,
      success_fun = success_logical
    )

  # - family
  priority_family <- c(
    # Lycophytes
    "Lycopodiaceae",
    "Isoetaceae",
    "Selaginellaceae",
    # Ferns are determined from FTOL
    rev(families_in_phy_order)
  )

  family_check <- ppg_print |>
    filter(taxonRank == "family") |>
    assert(
      in_set(priority_family),
      scientificName,
      success_fun = success_logical
    )

  # Compile all priorities
  priority_sort <- c(
    priority_class,
    priority_subclass,
    priority_order,
    priority_suborder,
    priority_family
  )

  # Convert to taxonlist format
  ppg_print |>
    dplyr::select(
      TaxonConceptID = taxonID,
      TaxonUsageID = taxonID,
      TaxonName = scientificName,
      AuthorName = scientificNameAuthorship,
      Level = taxonRank,
      Parent = parentNameUsageID
    ) |>
    mutate(AcceptedName = TRUE) |>
    as.data.frame() |>
    taxlist::df2taxlist(levels = rev(higher_tax_levels_used))

}

#' Clean and Parse PPG II Supplementary Data
#'
#' Cleans and parses supplementary PPG II data, including type and
#' lectotypification information.
#'
#' @param ppgi_supp_data_raw Raw supplementary data as a data frame.
#'
#' @return A data frame with parsed and cleaned columns:
#'   - scientificName
#'   - scientificNameAuthorship
#'   - type_category
#'   - lectotype_designation
#'   - type_sci_name
#'   - type_author
#'   - circumscription
#'   - includes
#'   - monophyly
#'   - comments
#'
clean_ppgi_supp_data <- function(ppgi_supp_data_raw) {
  res <-
    ppgi_supp_data_raw |>
    janitor::clean_names() |>
    select(
      scientificName = taxon,
      scientificNameAuthorship = authority,
      type_lectotypification_reference,
      type_species_with_authority_and_basionym,
      circumscription,
      monophyly,
      includes,
      comments_published
    ) |>
    mutate(
      across(
        everything(),
        ~ na_if(., "TOREMOVE")
      )
    ) |>
    mutate(
      type_category = str_match(
        type_lectotypification_reference,
        "Type|Lectotype"
      )[, 1],
      lectotype_designation = str_extract(
        type_lectotypification_reference,
        "(?<=Lectotype \\(designated by )[^)]+"
      ),
      type_species_basionym = stringr::str_extract(
        type_species_with_authority_and_basionym,
        "(?<=\\(≡ )[^)]+"
      ),
      type_species = stringr::str_remove(
        type_species_with_authority_and_basionym,
        " \\(≡ .+\\)"
      )
    ) |>
    select(
      scientificName,
      scientificNameAuthorship,
      type_category,
      lectotype_designation,
      type_species,
      type_species_basionym,
      circumscription,
      includes,
      monophyly,
      comments = comments_published
    )
  # Parse type species into sciName + authorship
  type_name_parsed <- res |>
    filter(!is.na(type_species)) |>
    pull(type_species) |>
    unique() |>
    gn_parse_tidy() |>
    select(
      type_sci_name = canonicalfull,
      type_author = authorship,
      type_species = verbatim
    )

  # Add type name with authorship
  res |>
    left_join(
      type_name_parsed,
      by = "type_species"
    ) |>
    select(
      scientificName,
      scientificNameAuthorship,
      type_category,
      lectotype_designation,
      type_sci_name,
      type_author,
      circumscription,
      includes,
      monophyly,
      comments
    )
}

#' Prepare initial suppelementary PPG II data
#'
#' Use this as a template to start filling in supplemental data for PPG II
#'
#' @param ppgi_supp_data Cleaned PPG I supplementary data (from
#'   clean_ppgi_supp_data()).
#' @param ppg_taxdf Taxonomic data frame with at least columns
#'   taxonID, taxonRank, scientificName, and scientificNameAuthorship.
#'
#' @return A data frame joining taxonomic and supplementary data
#'
make_initial_ppgii_supp_data <- function(ppgi_supp_data, ppg_taxdf) {
  ppg_taxdf |>
    select(taxonID, taxonRank, scientificName, scientificNameAuthorship) |>
    left_join(
      ppgi_supp_data,
      by = c("scientificName", "scientificNameAuthorship"),
      relationship = "one-to-one"
    )
}
