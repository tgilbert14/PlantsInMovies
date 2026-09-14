# R/notebook.R
# ------------------------------------------------------------------------------
# Per-session field notebook for saved family snapshots. The main server passes
# reactive world(), family(), and family_rows() functions; no notebook state is
# stored globally or written to disk.
# ------------------------------------------------------------------------------

.notebook_max_notes <- 12L
.notebook_basis <- paste(
  "Distinct USDA symbols for this family in the saved state's checklist;",
  "percentage is the family share of that state's selected-world records"
)

.notebook_note_id <- function(world, family) {
  key <- enc2utf8(paste(world, family, sep = "\u001f"))
  paste0("note_", paste(sprintf("%02x", as.integer(charToRaw(key))), collapse = ""))
}

.notebook_as_time <- function(value) {
  if (inherits(value, "POSIXt")) {
    out <- as.POSIXct(value)
  } else if (is.numeric(value)) {
    out <- as.POSIXct(value, origin = "1970-01-01", tz = "UTC")
  } else {
    out <- as.POSIXct(value, tz = "UTC")
  }
  if (length(out) != 1L || is.na(out)) stop("captured_at must be one valid timestamp")
  out
}

.notebook_iso_time <- function(value) {
  format(.notebook_as_time(value), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.notebook_display_time <- function(value) {
  format(.notebook_as_time(value), "%b %d, %Y · %H:%M UTC", tz = "UTC")
}

.notebook_normalize_rows <- function(rows) {
  if (is.null(rows) || !is.data.frame(rows) || nrow(rows) == 0L) {
    return(list(ok = FALSE, reason = "empty", rows = NULL))
  }

  required <- c("State", "n", "percent")
  if (!all(required %in% names(rows))) {
    return(list(ok = FALSE, reason = "invalid", rows = NULL))
  }

  states <- as.character(rows$State)
  records <- suppressWarnings(as.numeric(as.character(rows$n)))
  shares <- suppressWarnings(as.numeric(as.character(rows$percent)))
  whole_records <- is.finite(records) & abs(records - round(records)) < 1e-8

  valid <- length(states) == length(records) && length(records) == length(shares) &&
    all(!is.na(states) & nzchar(trimws(states))) && !anyDuplicated(states) &&
    all(whole_records & records >= 0) &&
    all(is.finite(shares) & shares >= 0 & shares <= 100)

  if (!isTRUE(valid)) {
    return(list(ok = FALSE, reason = "invalid", rows = NULL))
  }

  normalized <- data.frame(
    State = states,
    n = as.integer(round(records)),
    percent = round(shares, 1),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  normalized <- normalized[order(-normalized$n, normalized$State), , drop = FALSE]
  rownames(normalized) <- NULL
  list(ok = TRUE, reason = NULL, rows = normalized)
}

.notebook_add_snapshot <- function(notes, world, family, rows,
                                   captured_at = Sys.time(),
                                   max_notes = .notebook_max_notes) {
  if (!is.list(notes)) stop("notes must be a list")
  max_notes <- as.integer(max_notes)
  if (length(max_notes) != 1L || is.na(max_notes) || max_notes < 1L) {
    stop("max_notes must be a positive integer")
  }

  valid_label <- function(x) {
    length(x) == 1L && !is.na(x) && nzchar(trimws(as.character(x)))
  }
  if (!valid_label(world) || !valid_label(family)) {
    return(list(ok = FALSE, reason = "invalid", notes = notes))
  }

  normalized <- .notebook_normalize_rows(rows)
  if (!normalized$ok) {
    return(list(ok = FALSE, reason = normalized$reason, notes = notes))
  }

  world <- as.character(world)
  family <- as.character(family)
  captured_at <- .notebook_as_time(captured_at)
  note_id <- .notebook_note_id(world, family)

  if (length(notes) && is.null(names(notes))) {
    names(notes) <- vapply(notes, function(note) note$id, character(1))
  }
  replaced <- note_id %in% names(notes)
  if (replaced) notes[[note_id]] <- NULL

  note <- list(
    id = note_id,
    world = world,
    family = family,
    captured_at = captured_at,
    rows = normalized$rows
  )
  notes[[note_id]] <- note

  dropped <- 0L
  if (length(notes) > max_notes) {
    dropped <- length(notes) - max_notes
    notes <- notes[-seq_len(dropped)]
  }

  list(
    ok = TRUE,
    reason = NULL,
    notes = notes,
    note = note,
    replaced = replaced,
    dropped = dropped
  )
}

.notebook_empty_csv <- function() {
  data.frame(
    World = character(),
    Family = character(),
    State = character(),
    Records = integer(),
    ShareOfWorldPercent = numeric(),
    SavedAt = character(),
    Source = character(),
    Basis = character(),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

.notebook_csv_data <- function(notes) {
  if (!length(notes)) return(.notebook_empty_csv())

  frames <- lapply(unname(notes), function(note) {
    data.frame(
      World = rep(note$world, nrow(note$rows)),
      Family = rep(note$family, nrow(note$rows)),
      State = note$rows$State,
      Records = note$rows$n,
      ShareOfWorldPercent = note$rows$percent,
      SavedAt = rep(.notebook_iso_time(note$captured_at), nrow(note$rows)),
      Source = rep("USDA PLANTS", nrow(note$rows)),
      Basis = rep(.notebook_basis, nrow(note$rows)),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  out
}

.notebook_format_records <- function(value) {
  formatC(as.integer(value), format = "d", big.mark = ",")
}

.notebook_format_percent <- function(value) {
  paste0(formatC(as.numeric(value), format = "f", digits = 1), "%")
}

.notebook_collect_matches <- function(event, world, family) {
  # Older clients sent only a numeric timestamp. Structured events bind a click
  # to the world and family that were actually rendered on its button.
  if (!is.list(event)) return(TRUE)
  if (is.null(event$world) || is.null(event$family)) return(FALSE)

  event_world <- as.character(event$world)
  event_family <- as.character(event$family)
  current_world <- as.character(world)
  current_family <- as.character(family)

  length(event_world) == 1L && length(event_family) == 1L &&
    length(current_world) == 1L && length(current_family) == 1L &&
    !is.na(event_world) && !is.na(event_family) &&
    identical(event_world, current_world) &&
    identical(event_family, current_family)
}

.notebook_card <- function(note) {
  rows <- note$rows[order(-note$rows$n, note$rows$State), , drop = FALSE]
  top_rows <- utils::head(rows, 3L)
  remainder <- nrow(rows) - nrow(top_rows)
  place_word <- if (nrow(rows) == 1L) "place" else "places"

  top_items <- lapply(seq_len(nrow(top_rows)), function(i) {
    row <- top_rows[i, , drop = FALSE]
    record_word <- if (row$n == 1L) "record" else "records"
    shiny::tags$li(
      class = "notebook-result",
      shiny::tags$div(
        class = "notebook-result-line",
        shiny::tags$strong(row$State),
        shiny::tags$span(
          paste(.notebook_format_records(row$n), record_word)
        )
      ),
      shiny::tags$p(
        paste0(
          .notebook_format_percent(row$percent),
          " of this state's ", note$world, " records"
        )
      )
    )
  })

  full_rows <- lapply(seq_len(nrow(rows)), function(i) {
    row <- rows[i, , drop = FALSE]
    shiny::tags$tr(
      shiny::tags$th(scope = "row", row$State),
      shiny::tags$td(.notebook_format_records(row$n)),
      shiny::tags$td(.notebook_format_percent(row$percent))
    )
  })

  shiny::tags$article(
    class = "notebook-card",
    `data-note-id` = note$id,
    shiny::tags$header(
      class = "notebook-card-header",
      shiny::tags$div(
        shiny::tags$p(class = "eyebrow", note$world),
        shiny::tags$h3(note$family),
        shiny::tags$p(
          class = "notebook-card-context",
          paste("Saved for", nrow(rows), place_word)
        )
      ),
      shiny::tags$button(
        type = "button",
        class = "notebook-remove",
        `data-remove-note` = note$id,
        `aria-label` = paste("Remove", note$family, "from the field notebook"),
        "Remove"
      )
    ),
    shiny::tags$time(
      class = "notebook-captured",
      datetime = .notebook_iso_time(note$captured_at),
      paste("Saved", .notebook_display_time(note$captured_at))
    ),
    shiny::tags$ul(class = "notebook-results", top_items),
    if (remainder > 0L) {
      shiny::tags$p(
        class = "notebook-remainder",
        paste("+", remainder, "more", if (remainder == 1L) "place" else "places", "in the full saved comparison")
      )
    },
    shiny::tags$details(
      class = "notebook-details",
      shiny::tags$summary(paste("View all", nrow(rows), "saved", place_word)),
      shiny::tags$div(
        class = "table-scroll",
        tabindex = "0",
        role = "region",
        `aria-label` = paste(note$family, "saved comparison for", note$world),
        shiny::tags$table(
          class = "notebook-table",
          shiny::tags$caption(
            class = "visually-hidden",
            paste("Full saved comparison of", note$family, "for", note$world)
          ),
          shiny::tags$thead(
            shiny::tags$tr(
              shiny::tags$th(scope = "col", "State or territory"),
              shiny::tags$th(scope = "col", "Records"),
              shiny::tags$th(scope = "col", paste0("Share of state's ", note$world, " records"))
            )
          ),
          shiny::tags$tbody(full_rows)
        )
      )
    )
  )
}

notebook_ui <- function() {
  shiny::tags$section(
    id = "notebook",
    class = "notebook-section",
    `aria-labelledby` = "notebook-heading",
    shiny::tags$div(
      class = "section-heading notebook-heading",
      shiny::tags$div(
        shiny::tags$p(class = "eyebrow", "FIELD NOTES"),
        shiny::tags$h2(
          id = "notebook-heading", tabindex = "-1", "Your field notebook"
        )
      ),
      shiny::tags$p(
        "Keep the current state counts. Up to 12 families. Saving a family again updates its saved counts."
      ),
      shiny::tags$p(
        class = "notebook-visit-note",
        "Saved for this visit. Download your notes before closing."
      )
    ),
    shiny::tags$div(
      class = "notebook-actions",
      shiny::uiOutput("notebook_download"),
      shiny::tags$button(
        type = "button",
        id = "clear-notebook",
        class = "notebook-clear",
        "Clear notebook"
      ),
      shiny::tags$div(
        class = "notebook-status",
        role = "status",
        `aria-live` = "polite",
        `aria-atomic` = "true",
        shiny::textOutput("notebook_status", inline = TRUE)
      )
    ),
    shiny::uiOutput("notebook_cards", class = "notebook-cards")
  )
}

# Called once inside the main server:
#   notebook <- notebook_server(input, output, session, world, family, family_rows)
#
# Returns reactive snapshots(), count(), and status() for optional integration.
# The browser script should send event-priority values to collect_family,
# remove_note (the data-remove-note value), and clear_notebook.
notebook_server <- function(input, output, session, world, family, family_rows) {
  if (!is.function(world) || !is.function(family) || !is.function(family_rows)) {
    stop("world, family, and family_rows must be reactive functions")
  }

  notes <- shiny::reactiveVal(list())
  status_message <- shiny::reactiveVal(
    "No notes saved yet. Open a family and save its current results."
  )

  shiny::observeEvent(input$collect_family, {
    event <- input$collect_family
    capture <- tryCatch(
      list(
        world = shiny::isolate(world()),
        family = shiny::isolate(family()),
        rows = shiny::isolate(family_rows())
      ),
      error = function(error) NULL
    )

    if (is.null(capture)) {
      status_message("These family notes are unavailable right now.")
      return(invisible(NULL))
    }

    if (!.notebook_collect_matches(event, capture$world, capture$family)) {
      status_message("The selection changed. Save the family again.")
      return(invisible(NULL))
    }

    result <- tryCatch(
      .notebook_add_snapshot(
        notes(), capture$world, capture$family, capture$rows,
        captured_at = Sys.time(), max_notes = .notebook_max_notes
      ),
      error = function(error) list(ok = FALSE, reason = "invalid")
    )

    if (!isTRUE(result$ok)) {
      if (identical(result$reason, "empty")) {
        status_message(
          "Choose at least one state or territory before saving this family."
        )
      } else {
        status_message("These family notes are unavailable right now.")
      }
      return(invisible(NULL))
    }

    notes(result$notes)
    session$sendCustomMessage(
      "notebook-saved",
      list(
        id = result$note$id,
        world = result$note$world,
        family = result$note$family,
        replaced = isTRUE(result$replaced),
        count = length(result$notes)
      )
    )
    verb <- if (isTRUE(result$replaced)) "Updated" else "Saved"
    place_word <- if (nrow(result$note$rows) == 1L) "place" else "places"
    message <- paste(
      verb, result$note$family, "from", result$note$world, "for",
      nrow(result$note$rows), paste0(place_word, ".")
    )
    if (result$dropped > 0L) {
      message <- paste(
        message,
        "The oldest note was removed to keep the 12-family limit."
      )
    }
    status_message(message)
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$remove_note, {
    event <- input$remove_note
    note_id <- if (is.list(event) && !is.null(event$id)) event$id else event
    note_id <- as.character(note_id)[1]
    current <- notes()

    if (!is.na(note_id) && note_id %in% names(current)) {
      removed <- current[[note_id]]
      current[[note_id]] <- NULL
      notes(current)
      status_message(paste("Removed", removed$family, "from", paste0(removed$world, ".")))
    } else {
      status_message("That note is no longer in the notebook.")
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$clear_notebook, {
    if (length(notes())) {
      notes(list())
      status_message("Field notebook cleared.")
    } else {
      status_message("The field notebook is already empty.")
    }
  }, ignoreInit = TRUE)

  output$notebook_cards <- shiny::renderUI({
    current <- notes()
    if (!length(current)) {
      return(shiny::tags$div(
        class = "notebook-empty",
        shiny::tags$h3("No notes saved yet."),
        shiny::tags$p(
          "Open a family above and save it to compare these counts later."
        )
      ))
    }
    shiny::tagList(lapply(rev(unname(current)), .notebook_card))
  })

  output$notebook_status <- shiny::renderText(status_message())

  output$notebook_download <- shiny::renderUI({
    if (!length(notes())) {
      return(shiny::tags$button(
        type = "button",
        class = "notebook-download is-disabled",
        disabled = "disabled",
        `aria-disabled` = "true",
        "Download notebook"
      ))
    }
    shiny::downloadButton(
      "notebook_csv", "Download notebook", class = "notebook-download"
    )
  })

  output$notebook_csv <- shiny::downloadHandler(
    filename = function() {
      paste0("plants-in-movies-field-notebook-", Sys.Date(), ".csv")
    },
    content = function(file) {
      current <- shiny::isolate(notes())
      shiny::req(length(current) > 0L)
      utils::write.csv(
        .notebook_csv_data(current), file,
        row.names = FALSE, na = "", fileEncoding = "UTF-8"
      )
    }
  )

  snapshots_reactive <- shiny::reactive(notes())
  count_reactive <- shiny::reactive(length(notes()))
  status_reactive <- shiny::reactive(status_message())

  invisible(list(
    snapshots = snapshots_reactive,
    count = count_reactive,
    status = status_reactive
  ))
}
