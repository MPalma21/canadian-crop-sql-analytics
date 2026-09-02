# Data dictionary

The project preserves the column names from the course snapshots and assigns explicit analytical units below.

## `annual_crop.csv`

| Field | Meaning | Unit |
|---|---|---|
| `CD_ID` | Crop observation identifier | Integer key |
| `YEAR` | Observation year | ISO date; year-end |
| `CROP_TYPE` | Crop category | Barley, canola, rye or wheat |
| `GEO` | Geography | Canada, Alberta or Saskatchewan |
| `SEEDED_AREA` | Area planted | Hectares |
| `HARVESTED_AREA` | Area harvested | Hectares |
| `PRODUCTION` | Harvested crop production | Metric tonnes |
| `AVG_YIELD` | Average crop yield | Kilograms per hectare |

## `monthly_farm_prices.csv`

| Field | Meaning | Unit |
|---|---|---|
| `CD_ID` | Farm-price observation identifier | Integer key |
| `DATE` | Price month | ISO date; first day of month |
| `CROP_TYPE` | Crop category | Barley, canola, rye or wheat |
| `GEO` | Province | Alberta or Saskatchewan |
| `PRICE_PRERMT` | Farm price | Canadian dollars per metric tonne |

## `daily_fx.csv` and `monthly_fx.csv`

| Field | Meaning | Unit |
|---|---|---|
| `DFX_ID` | Exchange-rate observation identifier | Integer key |
| `DATE` | Exchange-rate date or month | ISO date |
| `FXUSDCAD` | Canadian dollars required for one US dollar | CAD per USD |

The USD crop price is therefore calculated as `CAD per tonne / CAD per USD`.

## Coverage and limitations

- Annual crop data: 1965–2020.
- Monthly farm prices: 1985–2020.
- Monthly foreign exchange: 2017–2021.
- Only Alberta and Saskatchewan are available at the provincial level.
- Farm price is not a delivered procurement quote. Freight, grade, basis, storage, contracts and transaction fees are excluded.
