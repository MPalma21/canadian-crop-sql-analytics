WITH latest_production AS (
  SELECT
    YEAR AS production_year,
    PRODUCTION AS production_metric_tonnes,
    AVG_YIELD AS yield_kg_per_hectare
  FROM crop_data
  WHERE GEO = 'Canada'
    AND CROP_TYPE = ?
  ORDER BY YEAR DESC
  LIMIT 1
),
latest_price AS (
  SELECT
    p.DATE AS price_date,
    p.PRICE_PRERMT AS price_cad_per_tonne,
    fx.FXUSDCAD AS cad_per_usd,
    ROUND(p.PRICE_PRERMT / fx.FXUSDCAD, 2) AS price_usd_per_tonne
  FROM farm_prices AS p
  INNER JOIN monthly_fx AS fx
    ON p.DATE = fx.DATE
  WHERE p.CROP_TYPE = ?
    AND p.GEO = ?
  ORDER BY p.DATE DESC
  LIMIT 1
)
SELECT *
FROM latest_production
CROSS JOIN latest_price;
