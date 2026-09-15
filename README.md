# ppg

This repo houses the Pteridophyte Phylogeny Group (PPG) taxonomic database for ferns and lycophytes.

[Issues](https://github.com/pteridogroup/ppg/issues) are used to discuss taxonomic proposals by the PPG community, which are voted on monthly. All proposals are relative to [PPG I (2016)](https://doi.org/10.1111/jse.12229). To propose a taxonomic change, use the [taxonomic proposal template](https://github.com/pteridogroup/ppg/issues/new?assignees=&labels=taxonomic+proposal&template=taxonomic-proposal.yml). Proposals that pass by a 2/3 majority will be implemented in the taxonomic database. 

For more information about PPG, see the [PPG webpage](https://pteridogroup.github.io/).

**IMPORTANT**: if you want to [participate](#contributing), please read the [Project Guidelines](https://pteridogroup.github.io/guidelines.html) first.

## Format

The database is provided as [a CSV file](data/ppg.csv) in the [Darwin Core (DwC) format](https://dwc.tdwg.org/terms/#taxon) for taxonomic data.

A human readable summary of the same data is available as [a plain text file](data/ppg.md) in Markdown format.

## Versioning

As of **v2.0.0**, this repository contains the official PPG II taxonomic system, reflecting changes to the classification of ferns and lycophytes since [PPG I (2016)](https://doi.org/10.1111/jse.12229). See the PPG II publication for details. *(citation to be added)*

Version numbers follow a four-part scheme, `MAJOR.GENUS.SPECIES.DEV`:

- `MAJOR` — a wholesale revision of the classification, such as the
  transition from PPG I to PPG II.
- `GENUS` — bumped when a release changes the accepted classification at
  genus rank or above (e.g., a genus is added, merged, split, or
  resurrected from synonymy).
- `SPECIES` — bumped when a release includes at least one change at species
  rank or below (new species, synonymy changes, name corrections, etc.)
  without any genus-or-above change.
- `DEV` — identifies an in-progress development version between full
  releases; it is dropped from the version number once a release is
  issued (e.g. `v0.0.0.9009` was a dev version; `v2.0.0` is a release).

Most commits on `main` are automated daily data updates and are not
individually version-tagged; issuing a new version is a separate, manual
decision.

## Contributing

All taxonomic decisions are made by the PPG community.

Taxonomic proposals should be submitted as [issues](https://github.com/pteridogroup/ppg/issues/new?assignees=&labels=taxonomic+proposal&template=taxonomic-proposal.yml), which will be voted on monthly. Proposals may be commented upon in the [issue tracker](https://github.com/pteridogroup/ppg/issues). Voting is carried out separately via a Google Form survey circulated on the PPG mailing list. Any proposal receiving >2/3 support will be approved and implemented in the data.

Anybody is welcome to contribute. All participants must adhere to the [Code of Conduct](https://pteridogroup.github.io/coc.html). Please read the [Project Guidelines](https://pteridogroup.github.io/guidelines.html) before contributing.

## Automated updates

The data are refreshed daily by the `Update PPG data` GitHub Actions
workflow (`.github/workflows/update-ppg.yml`), which runs the `targets`
pipeline and commits any changed data files back to `main`. It can also be
triggered manually from the Actions tab, or via
`gh workflow run update-ppg.yml`.

## Running with Docker

The Docker image is only for local, interactive development; it is not used
by the automated update.

Mount gitconfig and ssh for authentication:

```
docker run --rm -dt \
  -v ${PWD}:/wd \
  -v $HOME/.gitconfig:/home/user/.gitconfig:ro \
  -v $HOME/.ssh:/home/user/.ssh:ro \
  -w /wd \
  joelnitta/ppg:latest bash
```

Then attach to the container:

```
docker exec -it $(docker ps -q --filter ancestor=joelnitta/ppg:latest) bash
```

## Data sources

Original data were kindly provided by Michael Hassler.

## References

Pteridophyte Phylogeny Group I (2016) A community-derived classification for extant lycophytes and ferns. Journal of Systematics and Evolution 54:563–603. https://doi.org/10.1111/jse.12229

## License

Data (files in `data_raw/` and `data/`) are made available under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license.

Code is under the [MIT](LICENSE) license.