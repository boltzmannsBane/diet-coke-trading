# Experimental!
# strategy.ua — Spread ratio calculation + signal generation
# Strategy: NG/Crude Oil ratio mean reversion
# Ratio = WTI / NG (higher = NG is cheaper relative to crude)
# Entry long NG:  ratio > mean + N*std (NG cheap)
# Entry short NG: ratio < mean - N*std (NG expensive)
# Exit: ratio returns near rolling mean

# --- Parameters ---
Lookback  ← 60
Threshold ← 2.0

# --- Statistical helpers ---
Mean ← ÷⊃⧻(/+)
Std  ← √ Mean ⁿ2 - Mean .

# --- Position update for fold ---
# Row = [entry_signal exit_signal], Prev = current position
# Returns new position
# new = entry * (prev==0) + prev * (¬exit)
UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌
  )
  +
)

# --- Load aligned data ---
&p "=== Computing Spread Strategy ==="
NgPrices  ← °json &fras "data/aligned_ng.json"
WtiPrices ← °json &fras "data/aligned_wti.json"
Dates     ← °json &fras "data/aligned_dates.json"
&p ⧻ NgPrices

# --- Compute ratio ---
Ratio ← ÷ NgPrices WtiPrices
&p "Ratio mean / std:"
&p Mean Ratio
&p Std Ratio

# --- Rolling statistics ---
RMean ← ⧈(Mean) Lookback Ratio
RStd  ← ⧈(Std) Lookback Ratio

# Trim to match rolling window output (drops first Lookback-1 bars)
Offset       ← - 1 Lookback
TrimmedRatio ← ↘ Offset Ratio
TrimmedDates ← ↘ Offset Dates
TrimmedNg    ← ↘ Offset NgPrices
TrimmedWti   ← ↘ Offset WtiPrices
&p ⧻ TrimmedRatio

# --- Bollinger-style bands ---
UpperBand ← + RMean × Threshold RStd
LowerBand ← - RMean × Threshold RStd

# --- Raw entry signals ---
# 1 = long NG (ratio above upper = NG is cheap relative to crude)
# -1 = short NG (ratio below lower = NG is expensive)
RawLong  ← > UpperBand TrimmedRatio
RawShort ← < LowerBand TrimmedRatio
RawEntry ← - RawShort RawLong

# --- Exit signal: ratio returns near mean ---
NearMean ← < × 0.5 RStd ⌵ - RMean TrimmedRatio

&p "Raw entry signals (long / short / flat):"
&p /+ = 1 RawEntry
&p /+ = ¯1 RawEntry
&p /+ = 0 RawEntry
&p "Exit signals (near mean):"
&p /+ NearMean

# --- Stateful position generation ---
# Pack [entry, exit] per bar as rows of a matrix
SignalRows ← ≡⊟ NearMean RawEntry

# Fold with scan output to get position at each bar
Positions ← ∧(. UpdatePos) SignalRows 0

&p "Position distribution (long / short / flat):"
&p /+ = 1 Positions
&p /+ = ¯1 Positions
&p /+ = 0 Positions

# --- Save strategy outputs ---
&fwa "data/signals.json" json Positions
&fwa "data/ratio.json" json TrimmedRatio
&fwa "data/upper_band.json" json UpperBand
&fwa "data/lower_band.json" json LowerBand
&fwa "data/rolling_mean.json" json RMean
&fwa "data/trimmed_dates.json" json TrimmedDates
&fwa "data/trimmed_ng.json" json TrimmedNg
&fwa "data/trimmed_wti.json" json TrimmedWti
&p "=== Saved strategy data ==="
