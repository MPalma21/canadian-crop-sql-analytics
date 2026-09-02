source(here::here("R", "analysis.R"))

test_that("snapshots satisfy schemas and business rules", {
  sources <- read_crop_sources()

  expect_true(nrow(sources$crop) > 100)
  expect_true(nrow(sources$prices) > 100)
  expect_s3_class(sources$crop$YEAR, "Date")
  expect_s3_class(sources$monthly_fx$DATE, "Date")
  expect_true(all(sources$crop$HARVESTED_AREA <= sources$crop$SEEDED_AREA))
  expect_equal(sum(is.na(sources$monthly_fx)), 0)
})

test_that("database is indexed and core queries return plausible results", {
  sources <- read_crop_sources()
  connection <- build_crop_database(sources)
  on.exit(DBI::dbDisconnect(connection), add = TRUE)

  indexes <- DBI::dbGetQuery(connection, "SELECT name FROM sqlite_master WHERE type = 'index'")$name
  yields <- top_crop_yields(connection, "Saskatchewan", 2000)
  prices <- recent_crop_prices(connection, "Barley")
  trends <- national_crop_trends(connection)
  latest <- latest_national_production(connection)

  expect_true(all(c("idx_crop_market", "idx_price_market") %in% indexes))
  expect_true(nrow(yields) > 0)
  expect_true(all(yields$average_yield_kg_per_hectare >= 0))
  expect_equal(nrow(prices), 12)
  expect_true(all(prices$price_usd_per_tonne > 0))
  expect_true(nrow(trends) > 0)
  expect_equal(length(unique(latest$YEAR)), 1)
  expect_equal(unique(format(latest$YEAR, "%Y")), "2020")
})

test_that("market queries preserve units and support decision scenarios", {
  connection <- build_crop_database(read_crop_sources())
  on.exit(DBI::dbDisconnect(connection), add = TRUE)

  snapshot <- crop_market_snapshot(connection, "Barley")
  shares <- provincial_supply_share(connection, "Barley", 2020)
  annual_prices <- annual_crop_prices(connection, "Barley")
  scenario <- procurement_scenario(connection, "Barley", volume_tonnes = 250)

  expect_equal(nrow(snapshot), 1)
  expect_true(snapshot$production_metric_tonnes > 0)
  expect_true(all(shares$national_share_pct >= 0 & shares$national_share_pct <= 100))
  expect_true(all(annual_prices$months_observed > 0 & annual_prices$months_observed <= 12))
  expect_equal(
    scenario$estimated_cost_cad,
    round(scenario$volume_tonnes * scenario$unit_price_cad, 2)
  )
})

test_that("validation rejects malformed data", {
  sources <- read_crop_sources()

  missing_column <- sources
  missing_column$crop$PRODUCTION <- NULL
  expect_error(validate_crop_sources(missing_column), "missing columns")

  negative_price <- sources
  negative_price$prices$PRICE_PRERMT[[1]] <- -1
  expect_error(validate_crop_sources(negative_price), "non-negative")

  duplicate_fx <- sources
  duplicate_fx$monthly_fx$DATE[[2]] <- duplicate_fx$monthly_fx$DATE[[1]]
  expect_error(validate_crop_sources(duplicate_fx), "dates must be unique")
})

test_that("public functions reject invalid parameters", {
  connection <- build_crop_database(read_crop_sources())
  on.exit(DBI::dbDisconnect(connection), add = TRUE)

  expect_error(national_crop_trends(connection, character()), "at least one crop")
  expect_error(procurement_scenario(connection, "Barley", volume_tonnes = 0), "positive")
  expect_error(read_sql("does-not-exist.sql"), "does not exist")
})
