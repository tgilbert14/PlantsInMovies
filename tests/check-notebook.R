#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[startsWith(args, "--file=")]
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)
} else {
  normalizePath("tests/check-notebook.R", mustWork = TRUE)
}
project_dir <- dirname(dirname(script_path))
old_dir <- setwd(project_dir)
on.exit(setwd(old_dir), add = TRUE)

suppressPackageStartupMessages(library(shiny))
source("R/notebook.R")

checks_run <- 0L
check <- function(condition, label) {
  if (length(condition) != 1L || is.na(condition) || !condition) {
    stop("FAIL: ", label, call. = FALSE)
  }
  checks_run <<- checks_run + 1L
  message(sprintf("ok %02d - %s", checks_run, label))
  invisible(TRUE)
}

message("Plants in Movies field notebook checks")

rows <- data.frame(
  State = c("California", "Arizona", "Maine", "Alaska", "Nevada"),
  n = c(868L, 675L, 393L, 41L, 312L),
  percent = c(42.4, 48.2, 63.8, 12.1, 51.0),
  stringsAsFactors = FALSE
)
t1 <- as.POSIXct("2026-09-14 18:00:00", tz = "UTC")
t2 <- as.POSIXct("2026-09-14 18:05:00", tz = "UTC")

ui_html <- as.character(notebook_ui())
check(
  grepl("Your field notebook", ui_html, fixed = TRUE) &&
    grepl('id="notebook"', ui_html, fixed = TRUE) &&
    grepl("Saved for this visit", ui_html, fixed = TRUE) &&
    grepl('id="notebook_cards"', ui_html, fixed = TRUE) &&
    grepl('id="notebook_download"', ui_html, fixed = TRUE),
  "notebook UI declares the heading, snapshot copy, cards, and download outlet"
)
check(
  grepl('id="notebook-heading" tabindex="-1"', ui_html, fixed = TRUE) &&
    grepl('id="clear-notebook"', ui_html, fixed = TRUE) &&
    grepl('role="status"', ui_html, fixed = TRUE) &&
    grepl('id="notebook_status"', ui_html, fixed = TRUE),
  "notebook UI exposes the focus target, clear control, and dedicated status region"
)

first <- .notebook_add_snapshot(list(), "Arrakis", "Poaceae", rows, t1)
check(
  first$ok && !first$replaced && length(first$notes) == 1L &&
    nrow(first$note$rows) == nrow(rows),
  "a snapshot copies every selected state's count and percentage"
)
check(
  grepl("^note_[0-9a-f]+$", first$note$id) &&
    identical(names(first$notes), first$note$id),
  "snapshot keys are deterministic internal safe IDs"
)

changed_rows <- rows
changed_rows$n[changed_rows$State == "Arizona"] <- 700L
changed_rows$percent[changed_rows$State == "Arizona"] <- 50.0
replacement <- .notebook_add_snapshot(
  first$notes, "Arrakis", "Poaceae", changed_rows, t2
)
check(
  replacement$ok && replacement$replaced && length(replacement$notes) == 1L &&
    replacement$note$rows$n[replacement$note$rows$State == "Arizona"] == 700L &&
    identical(.notebook_iso_time(replacement$note$captured_at), "2026-09-14T18:05:00Z"),
  "saving the same world and family replaces data and refreshes capture time"
)
check(
  first$note$rows$n[first$note$rows$State == "Arizona"] == 675L,
  "an earlier snapshot is not rewritten when current rows later change"
)

many <- list()
last_result <- NULL
for (i in seq_len(13L)) {
  last_result <- .notebook_add_snapshot(
    many,
    paste0("World ", i),
    paste0("Family ", i),
    rows[seq_len((i %% nrow(rows)) + 1L), , drop = FALSE],
    t1 + i
  )
  many <- last_result$notes
}
check(
  length(many) == 12L && last_result$dropped == 1L &&
    !.notebook_note_id("World 1", "Family 1") %in% names(many) &&
    .notebook_note_id("World 13", "Family 13") %in% names(many),
  "the thirteenth unique snapshot removes the oldest and keeps twelve"
)

empty_attempt <- .notebook_add_snapshot(
  many, "Arrakis", "Cactaceae", rows[0, ], t2
)
invalid_attempt <- .notebook_add_snapshot(
  many, "Arrakis", "Cactaceae", rows[, c("State", "n")], t2
)
check(
  !empty_attempt$ok && identical(empty_attempt$reason, "empty") &&
    identical(empty_attempt$notes, many) && !invalid_attempt$ok &&
    identical(invalid_attempt$reason, "invalid") &&
    identical(invalid_attempt$notes, many),
  "empty or invalid rows never create a saved snapshot"
)

card_html <- as.character(.notebook_card(first$note))
check(
  grepl("notebook-card", card_html, fixed = TRUE) &&
    grepl(paste0('data-remove-note="', first$note$id, '"'), card_html, fixed = TRUE) &&
    grepl("notebook-remainder", card_html, fixed = TRUE),
  "a card provides its safe removal ID, top three rows, and remainder count"
)
check(
  all(vapply(rows$State, grepl, logical(1), x = card_html, fixed = TRUE)) &&
    grepl("notebook-table", card_html, fixed = TRUE) &&
    grepl("12.1%", card_html, fixed = TRUE),
  "card details retain the full saved state table and percentage context"
)

escaped <- .notebook_add_snapshot(
  list(), "Arrakis <script>", "Poaceae & allies",
  data.frame(State = "<Arizona>", n = 1L, percent = 2.5), t1
)
escaped_html <- as.character(.notebook_card(escaped$note))
check(
  !grepl("<script>", escaped_html, fixed = TRUE) &&
    grepl("&lt;script&gt;", escaped_html, fixed = TRUE) &&
    grepl("Poaceae &amp; allies", escaped_html, fixed = TRUE) &&
    grepl("&lt;Arizona&gt;", escaped_html, fixed = TRUE),
  "world, family, and state values are HTML-escaped by tag builders"
)

csv <- .notebook_csv_data(first$notes)
expected_csv_columns <- c(
  "World", "Family", "State", "Records", "ShareOfWorldPercent",
  "SavedAt", "Source", "Basis"
)
check(
  identical(names(csv), expected_csv_columns) && nrow(csv) == nrow(rows) &&
    all(csv$Source == "USDA PLANTS") && all(nzchar(csv$Basis)),
  "CSV rows use the explicit notebook export contract and source"
)
check(
  all(csv$SavedAt == "2026-09-14T18:00:00Z") &&
    csv$Records[csv$State == "Arizona"] == 675L &&
    csv$ShareOfWorldPercent[csv$State == "Arizona"] == 48.2,
  "CSV preserves snapshot time, record counts, and world-share percentages"
)
check(
  nrow(.notebook_csv_data(list())) == 0L &&
    identical(names(.notebook_csv_data(list())), expected_csv_columns),
  "empty CSV data retains headers but contains no false records"
)

# Exercise the actual observers with a mock Shiny session. A small session proxy
# records custom messages so failed collections can be proven stamp-free.
shiny::testServer(function(input, output, session) {
  world_value <- shiny::reactiveVal("Arrakis")
  family_value <- shiny::reactiveVal("Poaceae")
  rows_value <- shiny::reactiveVal(rows[1:3, , drop = FALSE])
  sent_messages <- shiny::reactiveVal(list())
  session_proxy <- list(
    sendCustomMessage = function(type, message) {
      current <- shiny::isolate(sent_messages())
      sent_messages(append(current, list(list(type = type, message = message))))
    }
  )

  notebook <- notebook_server(
    input, output, session_proxy,
    world = shiny::reactive(world_value()),
    family = shiny::reactive(family_value()),
    family_rows = shiny::reactive(rows_value())
  )
}, {
  session$flushReact()
  session$setInputs(collect_family = 1)
  check(
    notebook$count() == 1L && length(sent_messages()) == 1L &&
      identical(sent_messages()[[1]]$type, "notebook-saved") &&
      identical(sent_messages()[[1]]$message$count, 1L),
    "server collection saves once and sends one earned-stamp message"
  )
  check(
    grepl("Saved Poaceae from Arrakis for 3 places", notebook$status(), fixed = TRUE) &&
      grepl("notebook_csv", output$notebook_download$html, fixed = TRUE),
    "successful collection updates status and enables the CSV control"
  )

  first_server_id <- names(notebook$snapshots())[[1]]
  updated <- rows[1:3, , drop = FALSE]
  updated$n[1] <- updated$n[1] + 10L
  rows_value(updated)
  family_value("Cactaceae")
  session$setInputs(collect_family = list(
    world = "Arrakis", family = "Poaceae", nonce = 2
  ))
  check(
    notebook$count() == 1L && length(sent_messages()) == 1L &&
      identical(notebook$status(), "The selection changed. Save the family again.") &&
      notebook$snapshots()[[1]]$family == "Poaceae" &&
      notebook$snapshots()[[1]]$rows$n[
        notebook$snapshots()[[1]]$rows$State == "California"
      ] == 868L,
    "a stale rendered selection saves nothing and sends no success event"
  )

  family_value("Poaceae")
  session$setInputs(collect_family = list(
    world = "Arrakis", family = "Poaceae", nonce = 3
  ))
  check(
    notebook$count() == 1L && length(sent_messages()) == 2L &&
      isTRUE(sent_messages()[[2]]$message$replaced) &&
      grepl("Updated Poaceae", notebook$status(), fixed = TRUE),
    "server replaces an existing world-family snapshot without duplicating it"
  )

  rows_value(NULL)
  session$setInputs(collect_family = list(
    world = "Arrakis", family = "Poaceae", nonce = 4
  ))
  check(
    notebook$count() == 1L && length(sent_messages()) == 2L &&
      grepl("Choose at least one state", notebook$status(), fixed = TRUE),
    "empty server collection gives feedback and sends no saved stamp"
  )

  session$setInputs(remove_note = first_server_id)
  check(
    notebook$count() == 0L && grepl("Removed Poaceae", notebook$status(), fixed = TRUE) &&
      grepl("disabled", output$notebook_download$html, fixed = TRUE) &&
      !grepl("notebook_csv", output$notebook_download$html, fixed = TRUE),
    "remove_note deletes only its safe ID and disables empty download"
  )

  rows_value(rows[1:2, , drop = FALSE])
  session$setInputs(collect_family = list(
    world = "Arrakis", family = "Poaceae", nonce = 5
  ))
  family_value("Cactaceae")
  session$setInputs(collect_family = list(
    world = "Arrakis", family = "Cactaceae", nonce = 6
  ))
  check(notebook$count() == 2L, "server retains distinct world-family snapshots")

  session$setInputs(clear_notebook = 1)
  check(
    notebook$count() == 0L &&
      identical(notebook$status(), "Field notebook cleared."),
    "clear_notebook removes every per-session snapshot"
  )
})

message(sprintf("PASS: %d notebook UI, snapshot, CSV, and server checks.", checks_run))
message("Usage: Rscript tests/check-notebook.R")
