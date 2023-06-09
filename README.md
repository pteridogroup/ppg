# ppg

This repo houses the Pteridophyte Phylogeny Group (PPG) taxonomic database for ferns and lycophytes.

[Issues](https://github.com/pteridogroup/ppg/issues) are used to discuss taxonomic proposals by the PPG community, which are voted on monthly. All proposals are relative to [PPG I (2016)](https://doi.org/10.1111/jse.12229). To propose a taxonomic change, use the [taxonomic proposal template](https://github.com/pteridogroup/ppg/issues/new?assignees=&labels=taxonomic+proposal&template=taxonomic-proposal.yml). Proposals that pass by a 2/3 majority will be implemented in the taxonomic database. 

For more information about PPG, see the [PPG webpage](https://pteridogroup.github.io/).

**IMPORTANT**: if you want to [participate](#contributing), please read the [Project Guidelines](https://pteridogroup.github.io/guidelines.html) first.

## Format

The database is provided as [a CSV file](data/ppg.csv) in the [Darwin Core (DwC) format](https://dwc.tdwg.org/terms/#taxon) for taxonomic data.

A human readable summary of the same data is available as [a plain text file](data/ppg.md) in Markdown format.

Currently, the database includes only names at the genus level and higher, but we intend to include species and infraspecific taxa in the future.

## Versioning

The data are currently being updated to reflect changes that have taken place since [PPG I (2016)](https://doi.org/10.1111/jse.12229). Once this is done, a version number will be assigned. Therefore, **these data should not be taken as the official PPG system until a version number is assigned**.

## Contributing

All taxonomic decisions are made by the PPG community.

Taxonomic proposals should be submitted as [issues](https://github.com/pteridogroup/ppg/issues/new?assignees=&labels=taxonomic+proposal&template=taxonomic-proposal.yml), which will be voted on monthly. Proposals may be commented upon in the [issue tracker](https://github.com/pteridogroup/ppg/issues). Voting is carried out separately via a Google Form survey circulated on the PPG mailing list. Any proposal receiving >2/3 support will be approved and implemented in the data.

Anybody is welcome to contribute. All participants must adhere to the [Code of Conduct](https://pteridogroup.github.io/coc.html). Please read the [Project Guidelines](https://pteridogroup.github.io/guidelines.html) before contributing.

## Data sources

Original data were kindly provided by Michael Hassler.

## References

Pteridophyte Phylogeny Group I (2016) A community-derived classification for extant lycophytes and ferns. Journal of Systematics and Evolution 54:563–603. https://doi.org/10.1111/jse.12229

## License

Data (files in `data_raw/` and `data/`) are made available under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license.

Code is under the [MIT](LICENSE) license.