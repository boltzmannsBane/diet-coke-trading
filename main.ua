# main.ua — Natural Gas Spread Trading Backtester
# Entry point: runs the full pipeline end-to-end
# 
# Strategy: NG/Crude Oil ratio mean reversion
# - Compute WTI/NG price ratio
# - Enter long NG when ratio > mean + 2σ AND ratio is falling (2-day reversal)
#   AND NG price > $3.50 (cyclical deviations more likely to revert)
# - Exit when ratio returns within 0.5σ of mean
# - Double stop-loss: trail 1.0σ + ratio 3.0σ
# - 60-day lookback, $100k starting capital

# ╔══════════════════════════════════════════════╗
# ║  NG / CRUDE OIL SPREAD TRADING BACKTESTER   ║
# ╚══════════════════════════════════════════════╝

# ============================================
# STEP 1: Load and align price data
# ============================================

# --- CSV Parsing ---
StripCr    ← ▽ ≠@\r .
HasPrice   ← > 1 ⧻ ⊜□ ≠@, . °□
ParseDate  ← °□⊢ ⊜□ ≠@, . °□
ParsePrice ← ⋕°□⊡1 ⊜□ ≠@, . °□

ParseCsv ← (
  ↘1 ⊜□ ≠@\n . StripCr &fras
  ▽ ≡HasPrice .
  ⊃(≡ParseDate|≡ParsePrice)
)

&p "╔══════════════════════════════════════════════╗"
&p "║  NG / CRUDE OIL SPREAD TRADING BACKTESTER   ║"
&p "╚══════════════════════════════════════════════╝"
&p ""
&p "--- Step 1: Loading Data ---"

ParseCsv "data/ng_daily.csv"
NgDates  ←
NgPrices ←
&p ⊂ "NG records:  " json ⧻ NgDates

ParseCsv "data/wti_daily.csv"
WtiDates  ←
WtiPrices ←
&p ⊂ "WTI records: " json ⧻ WtiDates

# Align by date
NgInWti      ← ∊ WtiDates NgDates
AlignedDates ← ▽ NgInWti NgDates
AlignedNg    ← ▽ NgInWti NgPrices
WtiIdx       ← ⨂ WtiDates AlignedDates
AlignedWti   ← ⊏ WtiIdx WtiPrices

&p ⊂ "Aligned:     " ⊂ json ⧻ AlignedDates ⊂ " (" ⊂ °□⊢ AlignedDates ⊂ " to " ⊂ °□⊣ AlignedDates ")"

# ============================================
# STEP 2: Strategy — Spread ratio + signals
# ============================================
&p ""
&p "--- Step 2: Strategy Computation ---"

Lookback  ← 60
Threshold ← 2.0

Mean ← ÷⊃⧻(/+)
Std  ← √ Mean ⁿ2 - Mean .

# Ratio = WTI / NG
Ratio ← ÷ AlignedNg AlignedWti
&p ⊂ "Ratio mean: " json ÷ 100 ⁅ × 100 Mean Ratio

# Rolling stats
RMean ← ⧈(Mean) Lookback Ratio
RStd  ← ⧈(Std) Lookback Ratio

# Trim to match window output
Offset       ← - 1 Lookback
TrimmedRatio ← ↘ Offset Ratio
TrimmedDates ← ↘ Offset AlignedDates
TrimmedNg    ← ↘ Offset AlignedNg
TrimmedWti   ← ↘ Offset AlignedWti

# Bands
UpperBand ← + RMean × Threshold RStd
LowerBand ← - RMean × Threshold RStd

# Momentum filter: 2-day ratio change for reversal confirmation
RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrimmedRatio
# Trim all arrays to match momentum window (avoids recursive re-binding)
MR     ← ↘ MomDrop TrimmedRatio
MDates ← ↘ MomDrop TrimmedDates
MNg    ← ↘ MomDrop TrimmedNg
MWti   ← ↘ MomDrop TrimmedWti
MUB    ← ↘ MomDrop UpperBand
MLB    ← ↘ MomDrop LowerBand
MRMn   ← ↘ MomDrop RMean
MRSt   ← ↘ MomDrop RStd

# Entry requires both threshold breach AND momentum reversal
# Long NG: ratio > upper band AND ratio is falling (reversal toward mean)
# Short NG: ratio < lower band AND ratio is rising (reversal toward mean)
RawLong  ← × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
# NG > $3.50 filter: entries at higher NG prices are more likely cyclical (revert)
FilterLong ← × > 3.5 MNg RawLong
RawEntry   ← - RawShort FilterLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR

# Stateful positions via fold
UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

# Fill-forward: carry last non-zero value
FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)

# Min with reset: on entry day reset to element, else take min
MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)

SignalRows ← ≡⊟ NearMean RawEntry
Positions  ← ∧(. UpdatePos) SignalRows 0

# Double stop-loss: trail 1.0σ + ratio 3.0σ
BaseFlat ← = 0 Positions
PrPe     ← ⊂ 0 ↘ ¯1 Positions
EntryDay ← × = 0 PrPe ≠ 0 Positions

# Trail stop: exit if ratio moves 1.0σ away from best point since entry
DistFromMean ← ⌵ - MRMn MR
MinDistRows  ← ≡⊟ EntryDay DistFromMean
RunMinDist   ← ∧(. MinResetFn) MinDistRows ∞
TrailDist    ← - RunMinDist DistFromMean
TrailStop    ← × ≠ 0 Positions > × 1.0 MRSt TrailDist

# Ratio stop: exit if ratio moves 3.0σ from entry ratio
EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR
RatioStop   ← × ≠ 0 Positions > × 3.0 MRSt RatioDist

# Apply whichever stop triggers first
DblStop  ← ↥ TrailStop RatioStop
StopRows ← ≡⊟ BaseFlat DblStop
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Positions ¬ Blocked

&p ⊂ "Long days:  " json /+ = 1 ModPos
&p ⊂ "Short days: " json /+ = ¯1 ModPos
&p ⊂ "Flat days:  " json /+ = 0 ModPos

# ============================================
# STEP 3: Backtesting
# ============================================
&p ""
&p "--- Step 3: Backtesting ---"

StartingCapital ← 100000
LegAlloc        ← ÷ 2 StartingCapital

# Daily returns
NgRet  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiRet ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

# Spread PnL
PosForRet ← ↘ ¯1 ModPos
DailyPnl  ← × PosForRet × LegAlloc - WtiRet NgRet

# Equity curve
Equity      ← + StartingCapital \+ DailyPnl
FinalEquity ← ⊣ Equity

&p ⊂ "Starting capital: $" json StartingCapital
&p ⊂ "Final equity:     $" json ⁅ FinalEquity

# ============================================
# STEP 4: Performance Metrics
# ============================================
&p ""
&p "--- Step 4: Performance Metrics ---"

Nn    ← ⧻ DailyPnl
Years ← ÷ 252 Nn
Rnd   ← ÷ 100 ⁅ × 100

# Total return
TotalReturn ← × 100 ÷ StartingCapital - StartingCapital FinalEquity

# Annualized return
AnnReturn ← × 100 - 1 ⁿ ÷ Years 1 ÷ StartingCapital FinalEquity

# Max drawdown
Peak        ← \↥ Equity
Drawdown    ← ÷ Peak - Equity Peak
MaxDrawdown ← × 100 /↥ Drawdown

# Sharpe ratio
DailyRet ← ÷ ↘ ¯1 Equity - ↘ ¯1 Equity ↘ 1 Equity
Sharpe   ← × √252 ÷ Std DailyRet Mean DailyRet

# Win rate
InPosition ← ≠ 0 ↘ ¯1 ModPos
ActivePnl  ← ▽ InPosition DailyPnl
WinRate    ← × 100 ÷ ⧻ ActivePnl /+ > 0 ActivePnl

# Trade count and duration
PrevPos     ← ↘ ¯1 ModPos
CurrPos     ← ↘ 1 ModPos
NumTrades   ← /+ × = 0 PrevPos ≠ 0 CurrPos
AvgDuration ← ÷ NumTrades /+ ≠ 0 ModPos

# Profit factor
GrossProfit  ← /+ ▽ > 0 ActivePnl ActivePnl
GrossLoss    ← /+ ▽ < 0 ActivePnl ActivePnl
ProfitFactor ← ÷ ⌵ GrossLoss GrossProfit

&p ""
&p "╔══════════════════════════════════════════════╗"
&p "║         BACKTEST PERFORMANCE SUMMARY         ║"
&p "╠══════════════════════════════════════════════╣"
&p ⊂ "║  Period:            " ⊂ json Rnd Years " years"
&p ⊂ "║  Total Return:      " ⊂ json Rnd TotalReturn "%"
&p ⊂ "║  Annualized Return: " ⊂ json Rnd AnnReturn "%"
&p ⊂ "║  Max Drawdown:      " ⊂ json Rnd MaxDrawdown "%"
&p ⊂ "║  Sharpe Ratio:      " json Rnd Sharpe
&p ⊂ "║  Win Rate:          " ⊂ json Rnd WinRate "%"
&p ⊂ "║  Trades:            " json NumTrades
&p ⊂ "║  Avg Duration:      " ⊂ json Rnd AvgDuration " days"
&p ⊂ "║  Profit Factor:     " json Rnd ProfitFactor
&p "║                                              ║"
&p "║  Strategy: NG/Crude + NG>3.50 + trail+ratio   ║"
&p ⊂ "║  Lookback: " ⊂ json Lookback ⊂ " days, Threshold: " ⊂ json Threshold " std"
&p "╚══════════════════════════════════════════════╝"

# --- Save all outputs for later use ---
&fwa "data/equity.json" json Equity
&fwa "data/daily_pnl.json" json DailyPnl
&fwa "data/signals.json" json ModPos
&fwa "data/ratio.json" json MR
&fwa "data/upper_band.json" json MUB
&fwa "data/lower_band.json" json MLB
&fwa "data/rolling_mean.json" json MRMn
&fwa "data/trimmed_dates.json" json MDates
&fwa "data/trimmed_ng.json" json MNg
&fwa "data/trimmed_wti.json" json MWti
&p ""
&p "All data saved to data/ directory."
