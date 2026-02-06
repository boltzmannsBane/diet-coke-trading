# find_drawdown.ua — Find peak-to-trough dates of max drawdown
StripCr    ← ▽ ≠@\r .
HasPrice   ← > 1 ⧻ ⊜□ ≠@, . °□
ParseDate  ← °□⊢ ⊜□ ≠@, . °□
ParsePrice ← ⋕°□⊡1 ⊜□ ≠@, . °□
ParseCsv ← (
  ↘1 ⊜□ ≠@\n . StripCr &fras
  ▽ ≡HasPrice .
  ⊃(≡ParseDate|≡ParsePrice)
)

ParseCsv "data/ng_daily.csv"
NgDates  ←
NgPrices ←
ParseCsv "data/wti_daily.csv"
WtiDates  ←
WtiPrices ←

NgInWti      ← ∊ WtiDates NgDates
AlignedDates ← ▽ NgInWti NgDates
AlignedNg    ← ▽ NgInWti NgPrices
WtiIdx       ← ⨂ WtiDates AlignedDates
AlignedWti   ← ⊏ WtiIdx WtiPrices
Ratio        ← ÷ AlignedNg AlignedWti

Mean            ← ÷⊃⧻(/+)
Std             ← √ Mean ⁿ2 - Mean .
Rnd             ← ÷ 100 ⁅ × 100
StartingCapital ← 100000
LegAlloc        ← ÷ 2 StartingCapital

UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

Lookback     ← 60
Threshold    ← 2.0
RMean        ← ⧈(Mean) Lookback Ratio
RStd         ← ⧈(Std) Lookback Ratio
Offset       ← - 1 Lookback
TrimmedRatio ← ↘ Offset Ratio
TrimmedDates ← ↘ Offset AlignedDates
TrimmedNg    ← ↘ Offset AlignedNg
TrimmedWti   ← ↘ Offset AlignedWti
UpperBand    ← + RMean × Threshold RStd
LowerBand    ← - RMean × Threshold RStd

RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrimmedRatio
MR       ← ↘ MomDrop TrimmedRatio
MDates   ← ↘ MomDrop TrimmedDates
MNg      ← ↘ MomDrop TrimmedNg
MWti     ← ↘ MomDrop TrimmedWti
MUB      ← ↘ MomDrop UpperBand
MLB      ← ↘ MomDrop LowerBand
MRMn     ← ↘ MomDrop RMean
MRSt     ← ↘ MomDrop RStd

RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Positions  ← ∧(. UpdatePos) SignalRows 0

NgRet     ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiRet    ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PosForRet ← ↘ ¯1 Positions
DailyPnl  ← × PosForRet × LegAlloc - WtiRet NgRet
Equity    ← + StartingCapital \+ DailyPnl

# Dates for equity curve (starts at day 2 since returns need 1 lag)
EqDates ← ↘ 1 MDates

# Find max drawdown period
Peak     ← \↥ Equity
Drawdown ← ÷ Peak - Equity Peak

# Find trough (max drawdown point)
MaxDd     ← /↥ Drawdown
TroughIdx ← ˜⨂ MaxDd Drawdown

# Find peak before trough (last time equity was at its peak)
# The peak index is where Peak[TroughIdx] first appears
PeakVal ← ⊡ TroughIdx Peak
PeakIdx ← ˜⨂ PeakVal Equity

&p "══════════════════════════════════════════════"
&p "MAX DRAWDOWN ANALYSIS"
&p "══════════════════════════════════════════════"
&p ⊂ "Max Drawdown: " ⊂ json Rnd × 100 MaxDd "%"
&p ⊂ "Peak date:    " °□ ⊡ PeakIdx EqDates
&p ⊂ "Peak equity:  $" json ⁅ ⊡ PeakIdx Equity
&p ⊂ "Trough date:  " °□ ⊡ TroughIdx EqDates
&p ⊂ "Trough equity: $" json ⁅ ⊡ TroughIdx Equity
&p ⊂ "Duration:     " ⊂ json - PeakIdx TroughIdx " trading days"
&p ""

# Also find the position during this period
&p "Position at peak:   "
&p json ⊡ PeakIdx Positions
&p "Position at trough: "
&p json ⊡ TroughIdx Positions
&p ""

# Show ratio, NG, WTI at key points
&p ⊂ "Ratio at peak:   " json Rnd ⊡ PeakIdx MR
&p ⊂ "Ratio at trough: " json Rnd ⊡ TroughIdx MR
&p ⊂ "NG at peak:      $" json Rnd ⊡ PeakIdx MNg
&p ⊂ "NG at trough:    $" json Rnd ⊡ TroughIdx MNg
&p ⊂ "WTI at peak:     $" json Rnd ⊡ PeakIdx MWti
&p ⊂ "WTI at trough:   $" json Rnd ⊡ TroughIdx MWti

# Show the 5 worst individual days during the drawdown
&p ""
&p "--- 10 worst PnL days in entire backtest ---"
# Sort daily PnL ascending, take first 10
SortedIdx ← ⍏ DailyPnl
WorstIdx  ← ↙ 10 SortedIdx
WorstPnl  ← ⊏ WorstIdx DailyPnl
WorstDate ← ⊏ WorstIdx EqDates
&p ≡(⊂ °□ ⊂ ": $" json ⁅) WorstDate WorstPnl
