SELECT
  p.DATE,
  p.CROP_TYPE,
  p.GEO,
  p.PRICE_PRERMT AS price_cad_per_tonne,
  fx.FXUSDCAD AS cad_per_usd,
  ROUND(p.PRICE_PRERMT / fx.FXUSDCAD, 2) AS price_usd_per_tonne
FROM farm_prices AS p
INNER JOIN monthly_fx AS fx
  ON p.DATE = fx.DATE
WHERE p.CROP_TYPE = ?
  AND p.GEO = ?
ORDER BY p.DATE DESC
LIMIT ?;
