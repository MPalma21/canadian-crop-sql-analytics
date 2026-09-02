# Analytical architecture

```mermaid
flowchart LR
  A[Course CSV snapshots] --> B[Schema and business-rule validation]
  B --> C[(Temporary SQLite database)]
  C --> D[Versioned parameterized SQL]
  D --> E[R analytical functions]
  E --> F[English Quarto report]
  E --> G[Spanish Quarto report]
  H[testthat] --> B
  H --> D
  I[GitHub Actions] --> H
  I --> F
  I --> G
```

The SQLite file is created during each execution and is never committed. The repository instead versions transparent CSV snapshots, validation rules, SQL queries and tests.

## Relational model

```mermaid
erDiagram
  CROP_DATA {
    integer CD_ID PK
    date YEAR
    text CROP_TYPE
    text GEO
    numeric SEEDED_AREA
    numeric HARVESTED_AREA
    numeric PRODUCTION
    numeric AVG_YIELD
  }
  FARM_PRICES {
    integer CD_ID PK
    date DATE
    text CROP_TYPE
    text GEO
    numeric PRICE_PRERMT
  }
  MONTHLY_FX {
    integer DFX_ID PK
    date DATE UK
    numeric FXUSDCAD
  }
  DAILY_FX {
    integer DFX_ID PK
    date DATE
    numeric FXUSDCAD
  }
  FARM_PRICES }o--|| MONTHLY_FX : "joins on DATE"
```

Crop production and farm prices describe the same crop and geography dimensions but have different time grains, so the report does not force a row-level relationship between them.
