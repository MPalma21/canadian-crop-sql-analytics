WITH latest_year AS (
  SELECT MAX(YEAR) AS year
  FROM crop_data
  WHERE GEO = 'Canada'
)
SELECT
  c.YEAR,
  c.CROP_TYPE,
  c.SEEDED_AREA AS seeded_area_hectares,
  c.HARVESTED_AREA AS harvested_area_hectares,
  c.PRODUCTION AS production_metric_tonnes,
  c.AVG_YIELD AS yield_kg_per_hectare
FROM crop_data AS c
INNER JOIN latest_year AS y
  ON c.YEAR = y.year
WHERE c.GEO = 'Canada'
ORDER BY c.PRODUCTION DESC;
