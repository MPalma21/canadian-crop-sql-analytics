# Canadian Crop SQL Analytics

[![Validate Quarto project](https://github.com/MPalma21/canadian-crop-sql-analytics/actions/workflows/validate.yml/badge.svg)](https://github.com/MPalma21/canadian-crop-sql-analytics/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-2A9D8F.svg)](LICENSE)
[![R](https://img.shields.io/badge/R-4.6.1-276DC3.svg)](https://www.r-project.org/)
[![Quarto](https://img.shields.io/badge/Quarto-1.8-39729E.svg)](https://quarto.org/)

A bilingual, reproducible market-intelligence case study combining Canadian crop production, provincial farm prices and CAD/USD exchange rates in a temporary SQLite database.

Proyecto bilingüe y reproducible que integra producción agrícola canadiense, precios provinciales y tasas CAD/USD en una base SQLite temporal.

## Portfolio value

- Validates four dated source snapshots with explicit business rules.
- Builds and indexes SQLite during execution; no opaque database artifact is committed.
- Keeps parameterized SQL in versioned `.sql` files.
- Publishes the same analytical layer in English and Spanish.
- Tests schemas, units, queries, indexes, failure cases and a procurement scenario.
- Renders the complete site in GitHub Actions and uploads it as an artifact.

## Key business outputs

1. Latest national production comparison for barley, canola, rye and wheat.
2. Long-run production trends for brewing and distilling grains.
3. Transparent provincial coverage and national-share calculations.
4. Saskatchewan barley prices expressed in CAD and USD per metric tonne.
5. An auditable 250-tonne procurement sensitivity scenario.

## Architecture

```text
Validated CSV snapshots
        ↓
Temporary indexed SQLite database
        ↓
Versioned parameterized SQL
        ↓
Tested R analytical functions
        ↓
Bilingual Quarto website
```

See the [architecture](docs/architecture.md) and [data dictionary](docs/data-dictionary.md) for the full relational model and units.

## Repository structure

```text
.
├── R/analysis.R                 # validated analytical API
├── sql/                         # parameterized SQL queries
├── data/                        # preserved transparent snapshots
├── data-raw/prepare-data.R      # validated snapshot refresh
├── docs/                        # architecture and data dictionary
├── tests/testthat/              # automated tests
├── index.qmd                    # English report
├── es/index.qmd                 # Spanish report
└── .github/workflows/           # CI validation and render
```

## Reproduce

Prerequisites: R 4.4+, Quarto 1.8+ and a working C/C++ build toolchain when required by R packages.

```bash
Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv')"
Rscript -e "renv::restore()"
Rscript tests/testthat.R
quarto render
```

Refreshing source snapshots is optional and occurs only when explicitly requested:

```bash
Rscript data-raw/prepare-data.R
```

The refresh script validates schemas before replacing committed files and writes row counts, file sizes and MD5 checksums to `data/SNAPSHOT_METADATA.csv`.

## Data provenance

The course snapshots originate from Statistics Canada materials distributed through the IBM Skills Network. Exact URLs and the snapshot date are recorded in [`data/SOURCES.txt`](data/SOURCES.txt). The analytical site is historical and does not claim to provide current prices or inventory.

- Original learning publication: [RPubs](https://rpubs.com/MPalmaR19/1296542)
- English report: `index.qmd`
- Reporte en español: `es/index.qmd`

## Interpretation boundary

Farm price multiplied by volume is not delivered cost. Freight, quality grades, storage, basis, hedging, financing, taxes and negotiated contract terms are deliberately excluded and documented.

## License

Code is released under the [MIT License](LICENSE). Source datasets retain their original terms.
