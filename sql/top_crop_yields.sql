SELECT
  CROP_TYPE,
  ROUND(AVG(AVG_YIELD), 1) AS average_yield_kg_per_hectare
FROM crop_data
WHERE GEO = ?
  AND CAST(strftime('%Y', YEAR) AS INTEGER) = ?
GROUP BY CROP_TYPE
ORDER BY average_yield_kg_per_hectare DESC
LIMIT ?;
