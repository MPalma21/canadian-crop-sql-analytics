SELECT
  CAST(strftime('%Y', p.DATE) AS INTEGER) AS year,
  ROUND(AVG(p.PRICE_PRERMT), 2) AS avg_price_cad,
  ROUND(AVG(p.PRICE_PRERMT / fx.FXUSDCAD), 2) AS avg_price_usd,
  COUNT(*) AS months_observed
FROM farm_prices AS p
INNER JOIN monthly_fx AS fx
  ON p.DATE = fx.DATE
WHERE p.CROP_TYPE = ?
  AND p.GEO = ?
GROUP BY CAST(strftime('%Y', p.DATE) AS INTEGER)
ORDER BY year;
