suppressWarnings(suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(ggplot2)
}))

crop_schema <- list(
  crop = c(
    "CD_ID", "YEAR", "CROP_TYPE", "GEO", "SEEDED_AREA",
    "HARVESTED_AREA", "PRODUCTION", "AVG_YIELD"
  ),
  daily_fx = c("DFX_ID", "DATE", "FXUSDCAD"),
  monthly_fx = c("DFX_ID", "DATE", "FXUSDCAD"),
  prices = c("CD_ID", "DATE", "CROP_TYPE", "GEO", "PRICE_PRERMT")
)

read_crop_sources <- function(data_dir = here::here("data")) {
  sources <- list(
    crop = read.csv(file.path(data_dir, "annual_crop.csv"), stringsAsFactors = FALSE),
    daily_fx = read.csv(file.path(data_dir, "daily_fx.csv"), stringsAsFactors = FALSE),
    monthly_fx = read.csv(file.path(data_dir, "monthly_fx.csv"), stringsAsFactors = FALSE),
    prices = read.csv(
      file.path(data_dir, "monthly_farm_prices.csv"),
      stringsAsFactors = FALSE
    )
  )

  sources$crop$YEAR <- as.Date(sources$crop$YEAR)
  sources$daily_fx$DATE <- as.Date(sources$daily_fx$DATE)
  sources$monthly_fx$DATE <- as.Date(sources$monthly_fx$DATE)
  sources$prices$DATE <- as.Date(sources$prices$DATE)

  validate_crop_sources(sources)
  sources
}

validate_crop_sources <- function(sources) {
  missing_tables <- setdiff(names(crop_schema), names(sources))
  if (length(missing_tables) > 0) {
    stop("Missing source tables: ", paste(missing_tables, collapse = ", "))
  }

  for (table_name in names(crop_schema)) {
    missing_columns <- setdiff(crop_schema[[table_name]], names(sources[[table_name]]))
    if (length(missing_columns) > 0) {
      stop(table_name, " is missing columns: ", paste(missing_columns, collapse = ", "))
    }
    if (nrow(sources[[table_name]]) == 0) {
      stop(table_name, " contains no records")
    }
  }

  date_fields <- list(crop = "YEAR", daily_fx = "DATE", monthly_fx = "DATE", prices = "DATE")
  for (table_name in names(date_fields)) {
    field <- date_fields[[table_name]]
    if (anyNA(sources[[table_name]][[field]])) {
      stop(table_name, " contains invalid or missing dates")
    }
  }

  if (anyDuplicated(sources$crop$CD_ID)) {
    stop("annual crop identifiers must be unique")
  }
  if (anyDuplicated(sources$daily_fx$DFX_ID)) {
    stop("daily FX identifiers must be unique")
  }
  if (anyDuplicated(sources$monthly_fx$DATE)) {
    stop("monthly FX dates must be unique")
  }
  if (anyDuplicated(sources$prices$CD_ID)) {
    stop("farm-price identifiers must be unique")
  }

  nonnegative_fields <- list(
    crop = c("SEEDED_AREA", "HARVESTED_AREA", "PRODUCTION", "AVG_YIELD"),
    daily_fx = "FXUSDCAD",
    monthly_fx = "FXUSDCAD",
    prices = "PRICE_PRERMT"
  )
  for (table_name in names(nonnegative_fields)) {
    for (field in nonnegative_fields[[table_name]]) {
      values <- sources[[table_name]][[field]]
      if (any(!is.finite(values)) || any(values < 0)) {
        stop(table_name, "$", field, " must contain finite non-negative values")
      }
    }
  }

  if (any(sources$crop$HARVESTED_AREA > sources$crop$SEEDED_AREA)) {
    stop("harvested area cannot exceed seeded area")
  }

  invisible(TRUE)
}

as_database_table <- function(data) {
  date_columns <- vapply(data, inherits, logical(1), what = "Date")
  data[date_columns] <- lapply(data[date_columns], format, format = "%Y-%m-%d")
  data
}

build_crop_database <- function(sources, database = tempfile(fileext = ".sqlite")) {
  validate_crop_sources(sources)
  connection <- dbConnect(RSQLite::SQLite(), database)

  tryCatch({
    dbWithTransaction(connection, {
      dbWriteTable(connection, "crop_data", as_database_table(sources$crop), overwrite = TRUE)
      dbWriteTable(connection, "daily_fx", as_database_table(sources$daily_fx), overwrite = TRUE)
      dbWriteTable(connection, "monthly_fx", as_database_table(sources$monthly_fx), overwrite = TRUE)
      dbWriteTable(connection, "farm_prices", as_database_table(sources$prices), overwrite = TRUE)

      dbExecute(connection, "CREATE UNIQUE INDEX idx_crop_id ON crop_data (CD_ID)")
      dbExecute(connection, "CREATE INDEX idx_crop_market ON crop_data (CROP_TYPE, GEO, YEAR)")
      dbExecute(connection, "CREATE UNIQUE INDEX idx_daily_fx_id ON daily_fx (DFX_ID)")
      dbExecute(connection, "CREATE UNIQUE INDEX idx_monthly_fx_date ON monthly_fx (DATE)")
      dbExecute(connection, "CREATE UNIQUE INDEX idx_price_id ON farm_prices (CD_ID)")
      dbExecute(connection, "CREATE INDEX idx_price_market ON farm_prices (CROP_TYPE, GEO, DATE)")
    })
  }, error = function(error) {
    dbDisconnect(connection)
    stop(error)
  })

  connection
}

read_sql <- function(filename, sql_dir = here::here("sql")) {
  path <- file.path(sql_dir, filename)
  if (!file.exists(path)) {
    stop("SQL file does not exist: ", path)
  }
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

top_crop_yields <- function(connection, geography, year, limit = 5L) {
  dbGetQuery(
    connection,
    read_sql("top_crop_yields.sql"),
    params = list(geography, as.integer(year), as.integer(limit))
  )
}

recent_crop_prices <- function(
  connection,
  crop = "Barley",
  geography = "Saskatchewan",
  limit = 12L
) {
  result <- dbGetQuery(
    connection,
    read_sql("recent_crop_prices.sql"),
    params = list(crop, geography, as.integer(limit))
  )
  result$DATE <- as.Date(result$DATE)
  result
}

recent_canola_prices <- function(connection, geography = "Saskatchewan", limit = 12L) {
  recent_crop_prices(connection, "Canola", geography, limit)
}

national_crop_trends <- function(connection, crops = c("Barley", "Rye", "Wheat")) {
  if (length(crops) == 0) {
    stop("Select at least one crop")
  }
  placeholders <- paste(rep("?", length(crops)), collapse = ",")
  query <- paste0(
    "SELECT YEAR, CROP_TYPE, PRODUCTION, AVG_YIELD\n",
    "FROM crop_data\n",
    "WHERE GEO = 'Canada' AND CROP_TYPE IN (", placeholders, ")\n",
    "ORDER BY YEAR, CROP_TYPE"
  )
  result <- dbGetQuery(connection, query, params = as.list(crops))
  result$YEAR <- as.Date(result$YEAR)
  result
}

latest_national_production <- function(connection) {
  result <- dbGetQuery(connection, read_sql("latest_national_production.sql"))
  result$YEAR <- as.Date(result$YEAR)
  result
}

provincial_supply_share <- function(connection, crop, year = NULL) {
  if (is.null(year)) {
    year <- dbGetQuery(
      connection,
      "SELECT MAX(CAST(strftime('%Y', YEAR) AS INTEGER)) AS year
       FROM crop_data WHERE GEO = 'Canada' AND CROP_TYPE = ?",
      params = list(crop)
    )$year[[1]]
  }

  dbGetQuery(
    connection,
    read_sql("provincial_supply_share.sql"),
    params = list(crop, as.integer(year), crop, as.integer(year))
  )
}

crop_market_snapshot <- function(connection, crop, geography = "Saskatchewan") {
  result <- dbGetQuery(
    connection,
    read_sql("crop_market_snapshot.sql"),
    params = list(crop, crop, geography)
  )
  result$production_year <- as.Date(result$production_year)
  result$price_date <- as.Date(result$price_date)
  result
}

annual_crop_prices <- function(connection, crop, geography = "Saskatchewan") {
  dbGetQuery(
    connection,
    read_sql("annual_crop_prices.sql"),
    params = list(crop, geography)
  )
}

procurement_scenario <- function(
  connection,
  crop,
  geography = "Saskatchewan",
  volume_tonnes = 100
) {
  if (!is.numeric(volume_tonnes) || length(volume_tonnes) != 1 ||
      !is.finite(volume_tonnes) || volume_tonnes <= 0) {
    stop("volume_tonnes must be one positive finite number")
  }

  snapshot <- crop_market_snapshot(connection, crop, geography)
  snapshot |>
    transmute(
      crop,
      geography,
      price_date,
      volume_tonnes,
      unit_price_cad = price_cad_per_tonne,
      unit_price_usd = price_usd_per_tonne,
      estimated_cost_cad = round(volume_tonnes * price_cad_per_tonne, 2),
      estimated_cost_usd = round(volume_tonnes * price_usd_per_tonne, 2)
    )
}

data_quality_summary <- function(sources) {
  data.frame(
    dataset = c("Annual crop", "Daily FX", "Monthly FX", "Farm prices"),
    records = unname(vapply(sources, nrow, integer(1))),
    first_date = as.Date(c(
      min(sources$crop$YEAR),
      min(sources$daily_fx$DATE),
      min(sources$monthly_fx$DATE),
      min(sources$prices$DATE)
    ), origin = "1970-01-01"),
    last_date = as.Date(c(
      max(sources$crop$YEAR),
      max(sources$daily_fx$DATE),
      max(sources$monthly_fx$DATE),
      max(sources$prices$DATE)
    ), origin = "1970-01-01"),
    missing_cells = c(
      sum(is.na(sources$crop)),
      sum(is.na(sources$daily_fx)),
      sum(is.na(sources$monthly_fx)),
      sum(is.na(sources$prices))
    )
  )
}

plot_crop_trends <- function(data, language = c("en", "es")) {
  language <- match.arg(language)
  labels <- if (language == "en") {
    c(
      title = "Canadian grain production over time",
      subtitle = "National production, 1965–2020",
      x = "Year", y = "Production (metric tonnes)", color = "Crop"
    )
  } else {
    c(
      title = "Producción canadiense de granos a través del tiempo",
      subtitle = "Producción nacional, 1965–2020",
      x = "Año", y = "Producción (toneladas métricas)", color = "Cultivo"
    )
  }

  ggplot(data, aes(YEAR, PRODUCTION, color = CROP_TYPE)) +
    geom_line(linewidth = 0.9) +
    scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale())) +
    scale_color_viridis_d(end = 0.85) +
    labs(
      title = labels[["title"]], subtitle = labels[["subtitle"]],
      x = labels[["x"]], y = labels[["y"]], color = labels[["color"]]
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

plot_price_history <- function(data, language = c("en", "es")) {
  language <- match.arg(language)
  labels <- if (language == "en") {
    c(
      title = "Annual farm price in two currencies",
      subtitle = "Saskatchewan barley where price and FX data overlap",
      x = "Year", y = "Price per metric tonne", color = "Currency"
    )
  } else {
    c(
      title = "Precio agrícola anual en dos monedas",
      subtitle = "Cebada de Saskatchewan donde coinciden precios y tasa de cambio",
      x = "Año", y = "Precio por tonelada métrica", color = "Moneda"
    )
  }

  plot_data <- rbind(
    data.frame(year = data$year, currency = "CAD", price = data$avg_price_cad),
    data.frame(year = data$year, currency = "USD", price = data$avg_price_usd)
  )

  ggplot(plot_data, aes(year, price, color = currency)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    scale_color_manual(values = c(CAD = "#2A9D8F", USD = "#E76F51")) +
    scale_x_continuous(breaks = sort(unique(plot_data$year))) +
    labs(
      title = labels[["title"]], subtitle = labels[["subtitle"]],
      x = labels[["x"]], y = labels[["y"]], color = labels[["color"]]
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}
