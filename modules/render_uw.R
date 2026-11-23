# render_uw.R ---------------------------------------------------------------
# Render Quarto (.qmd) activity files to standalone, UW–Madison-branded HTML
# (UW Theme 2.0 look: Red Hat fonts, UW header/crest, dark UW footer,
# branded Quarto callouts). Output is a single self-contained .html per qmd,
# ready to upload and link to directly, outside WiscWeb/WordPress.
#
# Template assets live in modules/uw_brand/:
#   uw-brand.scss     Quarto theme layer (colors, type, callouts, tables, print)
#   uw-fonts.css      @font-face for Red Hat Display / Red Hat Text (fonts/)
#   header.html       UW global bar + crest + site title + STAR site menu
#                     (menu links are hard-coded here; edit if the site menu changes)
#   footer.html       UW footer                              ({{placeholders}})
#   fix-callouts.lua  repairs `::: {callout}` and typos like `callut`
#   uw-dividers.lua   styles `------` section dividers UW red; `------` used
#                     as write-in lines stays a plain gray rule
#
# Requires: Quarto CLI (bundled with RStudio/Positron), purrr, stringr, tibble.
# The source .qmd files are not modified, and their existing .html is not
# overwritten (output goes to `out_dir`).
#
# Usage (from the aud_support project root):
#   source("modules/render_uw.R")
#   render_uw("modules/activities_qmd/urge_surfing_practice.qmd")
#   render_uw_dir("modules/activities_qmd")            # all qmd files
# ---------------------------------------------------------------------------

library(purrr)
library(stringr)
library(tibble)

uw_defaults <- list(
  template_dir  = file.path("modules", "uw_brand"),
  out_dir       = file.path("modules", "activities_uw_html"),
  site_title    = "STAR Study",
  site_tagline  = "ARC, UW Department of Psychology",
  site_url      = "https://starstudy.wisc.edu/",
  contact_email = "schneck2@wisc.edu"
)

# -- helpers ----------------------------------------------------------------

uw_quarto_bin <- function() {
  bin <- if (requireNamespace("quarto", quietly = TRUE)) quarto::quarto_path() else ""
  if (is.null(bin) || !nzchar(bin)) bin <- Sys.which("quarto")
  if (!nzchar(bin)) stop("Quarto CLI not found. Install it or the `quarto` R package.")
  unname(bin)
}

uw_path <- function(x) normalizePath(x, winslash = "/", mustWork = TRUE)

html_escape <- function(x) {
  x |>
    str_replace_all("&", "&amp;") |>
    str_replace_all("<", "&lt;") |>
    str_replace_all(">", "&gt;") |>
    str_replace_all('"', "&quot;")
}

fill_template <- function(file, values) {
  txt <- readLines(file, warn = FALSE, encoding = "UTF-8") |> paste(collapse = "\n")
  for (nm in names(values)) txt <- str_replace_all(txt, fixed(str_c("{{", nm, "}}")), values[[nm]])
  out <- tempfile(fileext = ".html")
  writeLines(txt, out, useBytes = TRUE)
  uw_path(out)
}

# Page <title>: YAML title if present, otherwise first markdown heading
page_title <- function(qmd) {
  lines <- readLines(qmd, warn = FALSE, encoding = "UTF-8")
  yaml_title <- lines |> str_subset("^title:\\s*") |> head(1) |>
    str_remove("^title:\\s*") |> str_remove_all("^[\"']|[\"']$")
  if (length(yaml_title) == 1 && nzchar(yaml_title)) return(yaml_title)
  heading <- lines |> str_subset("^#{1,6}\\s+\\S") |> head(1) |>
    str_remove("^#{1,6}\\s+") |> str_remove("\\s*\\{.*\\}\\s*$") |>
    str_remove_all("[*_`]")
  if (length(heading) == 1) heading else tools::file_path_sans_ext(basename(qmd))
}

yaml_str <- function(x) str_c('"', str_replace_all(x, '(["\\\\])', "\\\\\\1"), '"')

# -- main -------------------------------------------------------------------

#' Render one qmd to UW-branded standalone HTML
#' @return path to the rendered html (invisibly)
render_uw <- function(input,
                      out_dir       = uw_defaults$out_dir,
                      template_dir  = uw_defaults$template_dir,
                      site_title    = uw_defaults$site_title,
                      site_tagline  = uw_defaults$site_tagline,
                      site_url      = uw_defaults$site_url,
                      contact_email = uw_defaults$contact_email,
                      quiet         = TRUE) {
  stopifnot(file.exists(input))
  if (!dir.exists(template_dir)) stop("Template folder not found: ", template_dir)
  tdir <- uw_path(template_dir)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  header <- fill_template(file.path(tdir, "header.html"), list(
    site_title   = html_escape(site_title),
    site_tagline = html_escape(site_tagline),
    site_url     = html_escape(site_url)
  ))
  footer <- fill_template(file.path(tdir, "footer.html"), list(
    contact_email = html_escape(contact_email),
    year          = format(Sys.Date(), "%Y")
  ))
  on.exit(unlink(c(header, footer)), add = TRUE)

  title <- page_title(input)
  meta  <- tempfile(fileext = ".yml")
  on.exit(unlink(meta), add = TRUE)
  writeLines(c(
    str_c("theme: [default, ", yaml_str(str_c(tdir, "/uw-brand.scss")), "]"),
    str_c("css: ", yaml_str(str_c(tdir, "/uw-fonts.css"))),
    str_c("include-before-body: ", yaml_str(header)),
    str_c("include-after-body: ", yaml_str(footer)),
    "filters:",
    str_c("  - path: ", yaml_str(str_c(tdir, "/fix-callouts.lua"))),
    "    at: pre-ast",
    str_c("  - path: ", yaml_str(str_c(tdir, "/uw-dividers.lua"))),
    "    at: pre-ast",
    "embed-resources: true",
    "toc: false",
    "lang: en",
    str_c("pagetitle: ", yaml_str(str_c(title, " | ", site_title)))
  ), meta, useBytes = TRUE)

  # Render next to the source (so relative image paths still resolve) under a
  # temporary name, then move into out_dir. Never touches <name>.html.
  stem      <- tools::file_path_sans_ext(basename(input))
  src_dir   <- uw_path(dirname(input))
  tmp_name  <- str_c(stem, ".uw-tmp.html")
  tmp_out   <- file.path(src_dir, tmp_name)
  final     <- file.path(uw_path(out_dir), str_c(stem, ".html"))
  libs_dir  <- file.path(src_dir, str_c(stem, "_files"))
  had_libs  <- dir.exists(libs_dir)
  quarto    <- uw_quarto_bin()

  # Quarto must run from the qmd's folder for --output + embed-resources
  owd <- setwd(src_dir)
  on.exit(setwd(owd), add = TRUE)
  log <- suppressWarnings(system2(
    quarto,
    c("render", shQuote(basename(input)), "--to", "html",
      "--metadata-file", shQuote(meta),
      "--output", shQuote(tmp_name), if (quiet) "--quiet"),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(log, "status") %||% 0L
  if (!had_libs) unlink(libs_dir, recursive = TRUE)

  # surface callout fixes / warnings even in quiet mode
  notes <- str_subset(log, "\\[uw-brand\\]|WARN|ERROR")
  if (length(notes)) message(basename(input), ":\n  ", str_c(notes, collapse = "\n  "))

  if (status != 0 || !file.exists(tmp_out)) {
    stop("Quarto failed for ", input, ":\n", str_c(tail(log, 20), collapse = "\n"))
  }
  file.copy(tmp_out, final, overwrite = TRUE)
  unlink(tmp_out)
  unlink(file.path(src_dir, str_c(stem, ".uw-tmp_files")), recursive = TRUE)

  if (!quiet) message("Wrote ", final)
  invisible(final)
}

#' Render every qmd in a folder; returns a tibble of results
render_uw_dir <- function(in_dir = file.path("modules", "activities_qmd"),
                          out_dir = uw_defaults$out_dir,
                          pattern = "\\.qmd$",
                          ...) {
  files <- list.files(in_dir, pattern = pattern, full.names = TRUE)
  message("Rendering ", length(files), " files to ", out_dir, " ...")
  safe_render <- safely(render_uw)
  res <- files |>
    map(\(f) safe_render(f, out_dir = out_dir, ...)) |>
    set_names(basename(files))
  out <- tibble(
    file   = names(res),
    output = map_chr(res, \(r) r$result %||% NA_character_),
    error  = map_chr(res, \(r) if (is.null(r$error)) NA_character_ else conditionMessage(r$error))
  )
  n_err <- sum(!is.na(out$error))
  message("Done: ", nrow(out) - n_err, " rendered, ", n_err, " failed.")
  out
}

# Example -------------------------------------------------------------------
# source("modules/render_uw.R")
# render_uw("modules/activities_qmd/urge_surfing_practice.qmd", quiet = FALSE)
# results <- render_uw_dir()
# results |> dplyr::filter(!is.na(error))
