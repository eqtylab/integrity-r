# NAME
#     sample-verifiable-plot.R - Generate a verifiable population plot
#
# SYNOPSIS
#     Rscript sample-verifiable-plot.R
#
# DESCRIPTION
#     Reads population data (Year, Population) from a CSV file, generates a
#     line chart with ggplot2, and records the input -> computation -> output
#     lineage in a local EQTY manifest.
#
#     This example wraps the plotting function with integrity_compute(), which
#     records a computation node with its declared input and produced output.
#
# ARGUMENTS
#     None.
#
# DEPENDENCIES
#     R packages: eqty.sdk.r, ggplot2, scales
library(eqty.sdk.r)
library(ggplot2)
library(scales)

ctx <- Context$new("Population plot example")

invisible(integrity_init(default_context = ctx))

signer <- Signer$load_or_create(name = "eqty-r-population-plot")

invisible(integrity_set_active_signer(signer))
signer_did <- DID$from_signer(
  signer,
  name = "Bob",
  description = "Local signer"
)

output_folder <- "./output"
population_path <- "./data/population.csv"

cat("Using population data from: ", population_path, "\n", sep = "")

# Create the input Dataset from the CSV path.
d_pop <- Dataset$with_context(ctx)$from_path(population_path,
  name = "Population Data",
  description = "World population data",
  `_store` = TRUE
)

plot_configuration <- Configuration$with_context(ctx)$from_object(
  integrity_dict(
    line_color = "firebrick",
    image_width = 8,
    image_height = 5,
    image_dpi = 300
  ),
  name = "Population Plot Configuration",
  description = "Visual and image-export settings for the population plot",
  `_store` = TRUE
)

output_filename <- file.path(output_folder, "population_plot_eqtysdk.jpg")

# Wrap the plotting function and declare its Dataset and Configuration inputs.
generate_population_plot <- integrity_compute(
  context = ctx,
  metadata = list(
    name = "Generate Population Plot",
    description = "Generates a population graph from CSV data"
  ),
  func = function(population_dataset, configuration) {
    registered_population_path <- as.character(
      integrity_resolve_path(population_dataset)
    )
    settings <- configuration$value
    pop_data <- utils::read.csv(
      registered_population_path,
      sep = "",
      header = TRUE
    )
    current_time <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")

    plot <- ggplot2::ggplot(
      pop_data,
      ggplot2::aes(x = year, y = population)
    ) +
      ggplot2::geom_line(
        color = as.character(settings$line_color),
        linewidth = 1
      ) +
      ggplot2::geom_point(
        color = as.character(settings$line_color),
        size = 0.5,
        alpha = 0.5
      ) +
      ggplot2::scale_y_continuous(
        labels = scales::label_number(scale_cut = scales::cut_short_scale())
      ) +
      ggplot2::theme_minimal() +
      ggplot2::labs(
        title = "Global Population: 2000-2025",
        subtitle = "Data Source: Worldometers",
        caption = paste("Generated:", current_time),
        x = "Year",
        y = "Total Population"
      )

    ggplot2::ggsave(
      output_filename,
      plot = plot,
      width = as.numeric(settings$image_width),
      height = as.numeric(settings$image_height),
      dpi = as.numeric(settings$image_dpi)
    )

    Dataset$with_context(ctx)$from_path(
      output_filename,
      name = "Population Plot",
      description = "Graph of world population over time"
    )
  },
  `_store` = TRUE
)

d_plot <- generate_population_plot(d_pop, plot_configuration)
cat("Plot saved to: ", output_filename, "\n", sep = "")

# Export the context's statements and blobs to a manifest JSON file.
manifest_path <- integrity_path("output/manifest.json")
invisible(ctx$export(manifest_path))

cat("Manifest successfully generated and exported to output/manifest.json.\n")
