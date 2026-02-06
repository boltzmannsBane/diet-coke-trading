# data.ua — Load and align natural gas + crude oil price data

# StripCr: Remove \r characters
StripCr ← ▽ ≠@\r .

# HasPrice: Check if a CSV line has a non-empty price field
HasPrice ← > 1 ⧻ ⊜□ ≠@, . °□

# ParseDate: Extract date string from a CSV line
ParseDate ← °□⊢ ⊜□ ≠@, . °□

# ParsePrice: Extract price number from a CSV line
ParsePrice ← ⋕°□⊡1 ⊜□ ≠@, . °□

# ParseCsv: filepath -> dates prices (dates on top)
ParseCsv ← (
  ↘1 ⊜□ ≠@\n . StripCr &fras
  ▽ ≡HasPrice .
  ⊃(≡ParseDate|≡ParsePrice)
)

# --- Load both datasets ---
&p "=== Loading Natural Gas Data ==="
ParseCsv "data/ng_daily.csv"
NgDates  ←
NgPrices ←
&p ⧻ NgDates
&p °□⊢ NgDates
&p °□⊣ NgDates

&p "=== Loading WTI Crude Oil Data ==="
ParseCsv "data/wti_daily.csv"
WtiDates  ←
WtiPrices ←
&p ⧻ WtiDates
&p °□⊢ WtiDates
&p °□⊣ WtiDates

# --- Align by date (inner join) ---
# ∊ haystack needle: checks which needles are in the haystack
# So ∊ WtiDates NgDates = which NG dates are in WTI = mask over NgDates
&p "=== Aligning by Date ==="

# Mask: which NG dates appear in WTI dates?
NgInWti ← ∊ WtiDates NgDates
# Filter NG side to only common dates
AlignedDates ← ▽ NgInWti NgDates
AlignedNg    ← ▽ NgInWti NgPrices

# For each common date, find its position in WTI
# ⨂ searched_in searched_for
WtiIdx     ← ⨂ WtiDates AlignedDates
AlignedWti ← ⊏ WtiIdx WtiPrices

&p ⧻ AlignedDates

# --- Print first 5 rows ---
&p "=== First 5 Rows (date | NG | WTI) ==="
≡(
  &pf °□
  &pf " | "
  &pf json
  &pf " | "
  &p json
) ↙5 AlignedDates ↙5 AlignedNg ↙5 AlignedWti

# --- Print last 5 rows ---
&p "=== Last 5 Rows ==="
≡(
  &pf °□
  &pf " | "
  &pf json
  &pf " | "
  &p json
) ↙¯5 AlignedDates ↙¯5 AlignedNg ↙¯5 AlignedWti

# --- Save aligned data ---
&fwa "data/aligned_dates.json" json AlignedDates
&fwa "data/aligned_ng.json" json AlignedNg
&fwa "data/aligned_wti.json" json AlignedWti
&p "=== Saved aligned data to data/ ==="
