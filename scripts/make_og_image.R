#----------------------------------------------------------------------
# make_og_image.R - draws docs/og-image.png (1200x630), the social card for
# the Plants in Movies landing page. Self-contained base-R graphics in the
# herbarium palette (parchment + botanical green + the three world accents),
# matching the app's bs_theme and the cover.
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" scripts/make_og_image.R
#----------------------------------------------------------------------
ROOT <- getwd()
out  <- file.path(ROOT, "docs", "og-image.png")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)

paper <- "#F4EFE6"; paper2 <- "#FBF8F1"; ink <- "#22201C"
green <- "#3F7A52"; axis <- "#6E665A"
arrakis <- "#C9852A"; middle <- "#3F7A52"; nublar <- "#2E8A99"

png(out, width = 1200, height = 630, res = 144)
op <- par(mar = c(0, 0, 0, 0), bg = paper); on.exit({ par(op); dev.off() })
plot.new(); plot.window(xlim = c(0, 1200), ylim = c(0, 630), xaxs = "i", yaxs = "i")

# background: parchment with a soft top-left glow
rect(0, 0, 1200, 630, col = paper, border = NA)
for (i in seq(0, 1, length.out = 60))
  symbols(150, 560, circles = 30 + i * 820, inches = FALSE, add = TRUE,
          bg = grDevices::adjustcolor(paper2, alpha.f = 0.012), fg = NA)

# faint pressed-seed texture (a herbarium speckle)
set.seed(7)
for (k in 1:44)
  symbols(runif(1, 40, 1160), runif(1, 40, 595), circles = runif(1, 2, 6),
          inches = FALSE, add = TRUE, fg = NA,
          bg = grDevices::adjustcolor(green, alpha.f = runif(1, .03, .07)))

# the signature tricolor rule (Arrakis / Middle-earth / Isla Nublar)
ry <- 556; rw <- 150
rect(70,           ry, 70 + rw/3,   ry + 6, col = arrakis, border = NA)
rect(70 + rw/3,    ry, 70 + 2*rw/3, ry + 6, col = middle,  border = NA)
rect(70 + 2*rw/3,  ry, 70 + rw,     ry + 6, col = nublar,  border = NA)

# badge
text(70, 520, "DESERT DATA LABS · A FIELD GUIDE",
     col = green, cex = .92, font = 2, adj = 0)

# title (serif, to echo the app's Fraunces headings)
text(68, 446, "Plants in Movies", col = ink, cex = 3.6, font = 2, adj = 0, family = "serif")

# subtitle
text(70, 360, "Which US state's flora best matches each movie world?",
     col = axis, cex = 1.18, adj = 0)
text(70, 326, "Arrakis · Middle-earth · Isla Nublar, scored from USDA PLANTS data.",
     col = axis, cex = 1.04, adj = 0)

# stat chips
chips <- list(c("3", "movie worlds"), c("50", "states"),
              c("34,400", "species"), c("USDA", "PLANTS data"))
spine <- c(arrakis, middle, nublar, green)
x0 <- 70; gap <- 14; w <- 250; h <- 96; y1 <- 64
for (i in seq_along(chips)) {
  xl <- x0 + (i - 1) * (w + gap)
  rect(xl, y1, xl + w, y1 + h, col = grDevices::adjustcolor(green, .08), border = NA)
  rect(xl, y1, xl + 6, y1 + h, col = spine[i], border = NA)                # accent spine
  text(xl + 22, y1 + 62, chips[[i]][1], col = ink,  cex = 1.85, font = 2, adj = 0, family = "serif")
  text(xl + 22, y1 + 28, chips[[i]][2], col = axis, cex = .94, adj = 0)
}
cat("wrote", out, "\n")
