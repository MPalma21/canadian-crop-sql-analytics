WITH national AS (
  SELECT PRODUCTION
  FROM crop_data
  WHERE GEO = 'Canada'
    AND CROP_TYPE = ?
    AND CAST(strftime('%Y', YEAR) AS INTEGER) = ?
)
SELECT
  c.GEO AS geography,
  c.PRODUCTION AS production_metric_tonnes,
  ROUND(100.0 * c.PRODUCTION / national.PRODUCTION, 1) AS national_share_pct
FROM crop_data AS c
CROSS JOIN national
WHERE c.GEO <> 'Canada'
  AND c.CROP_TYPE = ?
  AND CAST(strftime('%Y', c.YEAR) AS INTEGER) = ?
ORDER BY c.PRODUCTION DESC;
