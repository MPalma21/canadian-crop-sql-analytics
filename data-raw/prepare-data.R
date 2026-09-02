dir.create("data", showWarnings = FALSE, recursive = TRUE)

sources <- c(
  annual_crop = "https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-RP0203EN-SkillsNetwork/labs/Practice%20Assignment/Annual_Crop_Data.csv",
  daily_fx = "https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-RP0203EN-SkillsNetwork/labs/Practice%20Assignment/Daily_FX.csv",
  monthly_fx = "https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-RP0203EN-SkillsNetwork/labs/Final%20Project/Monthly_FX.csv",
  monthly_farm_prices = "https://cf-courses-data.s3.us.cloud-object-storage.appdomain.cloud/IBM-RP0203EN-SkillsNetwork/labs/Final%20Project/Monthly_Farm_Prices.csv"
)

expected_columns <- list(
  annual_crop = c(
    "CD_ID", "YEAR", "CROP_TYPE", "GEO", "SEEDED_AREA",
    "HARVESTED_AREA", "PRODUCTION", "AVG_YIELD"
  ),
  daily_fx = c("DFX_ID", "DATE", "FXUSDCAD"),
  monthly_fx = c("DFX_ID", "DATE", "FXUSDCAD"),
  monthly_farm_prices = c("CD_ID", "DATE", "CROP_TYPE", "GEO", "PRICE_PRERMT")
)

downloaded <- vector("list", length(sources))
names(downloaded) <- names(sources)

for (source_name in names(sources)) {
  destination <- file.path("data", paste0(source_name, ".csv"))
  temporary <- tempfile(fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)

  download.file(sources[[source_name]], temporary, mode = "wb", quiet = TRUE)
  if (!file.exists(temporary) || file.info(temporary)$size == 0) {
    stop("Downloaded an empty file: ", source_name)
  }

  snapshot <- read.csv(temporary, stringsAsFactors = FALSE)
  missing_columns <- setdiff(expected_columns[[source_name]], names(snapshot))
  if (length(missing_columns) > 0 || nrow(snapshot) == 0) {
    stop(
      "Downloaded source failed validation: ", source_name,
      if (length(missing_columns) > 0) paste0("; missing ", paste(missing_columns, collapse = ", ")) else ""
    )
  }

  if (!file.copy(temporary, destination, overwrite = TRUE)) {
    stop("Could not replace snapshot: ", destination)
  }

  downloaded[[source_name]] <- data.frame(
    dataset = source_name,
    snapshot_date = as.character(Sys.Date()),
    rows = nrow(snapshot),
    bytes = file.info(destination)$size,
    md5 = unname(tools::md5sum(destination)),
    source_url = sources[[source_name]],
    stringsAsFactors = FALSE
  )
}

metadata <- do.call(rbind, downloaded)
write.csv(metadata, file.path("data", "SNAPSHOT_METADATA.csv"), row.names = FALSE)

writeLines(
  c(
    paste("snapshot_date:", Sys.Date()),
    paste(names(sources), sources, sep = ": ")
  ),
  file.path("data", "SOURCES.txt")
)

message("Validated and recorded ", length(sources), " source snapshots.")
