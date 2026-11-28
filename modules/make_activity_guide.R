# make_activity_guide.R --------------------------------------------------------
# Builds a readable PDF guide to the recovery activities from the two files
# the code uses, so the guide is never out of date:
#   modules/activity_descriptions.csv  title, type, url, involves, benefits
#   modules/activities.csv             which areas (features) each activity
#                                      serves, its order within each area,
#                                      and can_repeat
#
# GENERATED FILE: modules/activity_guide.pdf is built by this script and is
# listed in .gitignore, so it stays local and is never pushed. Rerun this
# script after any edit to either CSV, or the PDF will be out of date (its
# subtitle shows the date it was built). The intermediate .qmd is written to
# R's session temp folder, which R clears when the session ends.
#
# Requires: the Quarto CLI (1.4+; PDF via Typst, no LaTeX needed) and the
# tidyverse.
#
# Usage (from the aud_support project root):
#   source("modules/make_activity_guide.R")
# -----------------------------------------------------------------------------

library(tidyverse)

path_desc <- here::here("modules", "activity_descriptions.csv")
path_acts <- here::here("modules", "activities.csv")
path_out <- here::here("modules", "activity_guide.pdf")   # replaced on each run; git-ignored

# read -------------------------------------------------------------------------
desc <- read_csv(path_desc, show_col_types = FALSE)
acts <- read_csv(path_acts, show_col_types = FALSE)

# area columns sit between `activity` and `notes` in activities.csv; a number
# is the activity's order within that area
areas <- acts |>
  select(activity, locs_alcohol:location_variance) |>
  pivot_longer(-activity, names_to = "area", values_to = "order",
               values_drop_na = TRUE) |>
  mutate(area = factor(area, levels = names(select(acts, locs_alcohol:location_variance))))

guide <- desc |>
  left_join(select(acts, activity, can_repeat), by = "activity") |>
  arrange(str_to_lower(title))

# warn (do not stop) if the two files disagree on which activities exist
missing_desc <- setdiff(acts$activity, desc$activity)
missing_acts <- setdiff(desc$activity, acts$activity)
if (length(missing_desc) > 0) {
  warning("In activities.csv but not activity_descriptions.csv: ",
          str_c(missing_desc, collapse = ", "))
}
if (length(missing_acts) > 0) {
  warning("In activity_descriptions.csv but not activities.csv: ",
          str_c(missing_acts, collapse = ", "))
}

# build the document -------------------------------------------------------------
# backslash-escape characters that markdown would read as markup
esc <- function(x) str_replace_all(x, "([\\\\*_@$#<>\\[\\]`])", "\\\\\\1")

# heading anchor for each activity, so the area lists can link to it
anchor <- function(activity) str_c("act-", str_replace_all(activity, "_", "-"))

# part 1: for each area, its activities in the order they are given
area_section <- function(area_name) {
  rows <- areas |>
    filter(area == area_name) |>
    left_join(select(desc, activity, title), by = "activity") |>
    arrange(order, title)
  c(str_c("## ", area_name),
    "",
    str_c(seq_len(nrow(rows)), ". [", esc(rows$title), "](#",
          anchor(rows$activity), ")"),
    "")
}

# part 2: one entry per activity, A to Z by title
activity_entry <- function(activity, title, type, url, involves, benefits,
                           can_repeat) {
  its_areas <- areas |>
    filter(.data$activity == .env$activity) |>
    arrange(area)
  area_text <- if (nrow(its_areas) == 0) {
    "none"
  } else {
    str_c(esc(as.character(its_areas$area)), " (", its_areas$order, ")",
          collapse = ", ")
  }
  repeat_text <- case_when(isTRUE(can_repeat) ~ "yes",
                           isFALSE(can_repeat) ~ "no",
                           .default = "not set")
  c(str_c("## ", esc(title), " {#", anchor(activity), "}"),
    "",
    str_c("`", activity, "` | ", type, " | can repeat: ", repeat_text,
          " | [open page](", url, ")"),
    "",
    str_c("**Areas (order):** ", area_text),
    "",
    str_c("**Involves:** ", esc(involves)),
    "",
    str_c("**How it can help:** ", esc(benefits)),
    "")
}

doc <- c(
  "---",
  "title: \"Recovery Activities Guide\"",
  str_c("subtitle: \"Built ", format(Sys.Date(), "%Y-%m-%d"), " from activity_descriptions.csv and activities.csv\""),
  "format:",
  "  typst:",
  "    papersize: us-letter",
  "    margin:",
  "      x: 0.9in",
  "      y: 0.8in",
  "    fontsize: 10pt",
  "---",
  "",
  str_c(nrow(guide), " activities. Part 1 lists each area's activities in ",
        "the order they are given (titles link to Part 2). Part 2 describes ",
        "each activity, A to Z by title; numbers after an area are the ",
        "activity's order in that area."),
  "",
  "# Part 1: Activities by area",
  "",
  levels(areas$area) |> keep(\(a) a %in% areas$area) |> map(area_section) |> unlist(),
  "{{< pagebreak >}}",
  "",
  "# Part 2: Activities A to Z",
  "",
  pmap(select(guide, activity, title, type, url, involves, benefits, can_repeat),
       activity_entry) |> unlist()
)

# render -------------------------------------------------------------------------
dir_build <- file.path(tempdir(), "activity_guide")
dir.create(dir_build, showWarnings = FALSE)   # base R: no tidyverse equivalent
path_qmd <- file.path(dir_build, "activity_guide.qmd")
write_lines(doc, path_qmd)

# base R system2(): calls the Quarto CLI directly, so the quarto R package is
# not needed
status <- system2("quarto", c("render", shQuote(path_qmd), "--quiet"))
if (status != 0) stop("Quarto render failed; see the messages above.")

file.copy(file.path(dir_build, "activity_guide.pdf"), path_out,
          overwrite = TRUE)   # base R: no tidyverse equivalent for copying
message("Activity guide written to ", path_out)
