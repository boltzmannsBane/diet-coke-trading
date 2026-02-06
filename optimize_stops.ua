# Experimental!
# optimize_stops.ua — Stop-loss strategy sweep
# Tests 4 stop-loss types with parameter sweeps

# ============================================
# DATA LOADING
# ============================================
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

# ============================================
# HELPERS
# ============================================
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

# Fill-forward: carry last non-zero value
FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)

# Cumulative with reset: on entry day reset to element, else accumulate
CumResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(+|⊙◌)
)

# Min with reset: on entry day reset to element, else take min
MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)

# ============================================
# SHARED: Rolling stats + momentum filter + base positions
# ============================================
Lookback  ← 60
Threshold ← 2.0

RMean        ← ⧈(Mean) Lookback Ratio
RStd         ← ⧈(Std) Lookback Ratio
Offset       ← - 1 Lookback
TrimmedRatio ← ↘ Offset Ratio
TrimmedNg    ← ↘ Offset AlignedNg
TrimmedWti   ← ↘ Offset AlignedWti
UpperBand    ← + RMean × Threshold RStd
LowerBand    ← - RMean × Threshold RStd

# 2-day momentum filter
RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MR       ← ↘ 2 TrimmedRatio
MNg      ← ↘ 2 TrimmedNg
MWti     ← ↘ 2 TrimmedWti
MUB      ← ↘ 2 UpperBand
MLB      ← ↘ 2 LowerBand
MRMn     ← ↘ 2 RMean
MRSt     ← ↘ 2 RStd

RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0

# Returns (shared across all variants)
NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

# Base backtest for reference
BaseFlat ← = 0 Pos

# Entry detection (shared for strategies 1, 2, 4)
PrPe     ← ⊂ 0 ↘ ¯1 Pos
EntryDay ← × = 0 PrPe ≠ 0 Pos

# ============================================
# STRATEGY 1 SHARED: Entry ratios + ratio distance
# ============================================
EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR

# ============================================
# STRATEGY 2 SHARED: Cumulative trade PnL
# ============================================
BasePfR     ← ↘ ¯1 Pos
BaseDPnl    ← × BasePfR × LegAlloc - WtiR NgR
DPnlAligned ← ⊂ 0 BaseDPnl
CumPnlRows  ← ≡⊟ EntryDay DPnlAligned
CumTradePnl ← ∧(. CumResetFn) CumPnlRows 0

# ============================================
# STRATEGY 3 SHARED: Base equity drawdown
# ============================================
BaseEqt   ← + StartingCapital \+ BaseDPnl
BasePk    ← \↥ BaseEqt
BaseDD    ← ÷ BasePk - BaseEqt BasePk
DDAligned ← ⊂ 0 BaseDD

# ============================================
# STRATEGY 4 SHARED: Distance from mean + running min
# ============================================
DistFromMean ← ⌵ - MRMn MR
MinDistRows  ← ≡⊟ EntryDay DistFromMean
RunMinDist   ← ∧(. MinResetFn) MinDistRows ∞

# ============================================
# OUTPUT
# ============================================
&p ""
&p "╔════════════════════════════════════════════════════════════════════════════════╗"
&p "║                        STOP-LOSS OPTIMIZATION                               ║"
&p "╠════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                  | Sharpe | MaxDD% | AnnRet% | TotRet% | #Tr | PF   ║"
&p "╠════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ BASELINE (no stop) ═══════════════
PfR    ← ↘ ¯1 Pos
DPnl   ← × PfR × LegAlloc - WtiR NgR
Eqt    ← + StartingCapital \+ DPnl
Yrs    ← ÷ 252 ⧻ DPnl
TotRet ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk     ← \↥ Eqt
MaxDd  ← × 100 /↥ ÷ Pk - Eqt Pk
DRet   ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh     ← × √252 ÷ Std DRet Mean DRet
PrP    ← ↘ ¯1 Pos
CuP    ← ↘ 1 Pos
NT     ← /+ × = 0 PrP ≠ 0 CuP
InPos  ← ≠ 0 ↘ ¯1 Pos
APnl   ← ▽ InPos DPnl
GP     ← /+ ▽ > 0 APnl APnl
GL     ← /+ ▽ < 0 APnl APnl
PF     ← ÷ ⌵ GL GP
&pf "║ No stop (baseline)       | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# ════════════════════════════════════════════
# STRATEGY 1: RATIO STOP-LOSS
# Exit if ratio moves > Xσ from entry ratio
# ════════════════════════════════════════════
&p "╠════════════════════════════════════════════════════════════════════════════════╣"

# --- Ratio stop 0.5σ ---
StopMask ← × ≠ 0 Pos > × 0.5 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Ratio stop 0.5σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Ratio stop 1.0σ ---
StopMask ← × ≠ 0 Pos > × 1.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Ratio stop 1.0σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Ratio stop 1.5σ ---
StopMask ← × ≠ 0 Pos > × 1.5 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Ratio stop 1.5σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Ratio stop 2.0σ ---
StopMask ← × ≠ 0 Pos > × 2.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Ratio stop 2.0σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Ratio stop 3.0σ ---
StopMask ← × ≠ 0 Pos > × 3.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Ratio stop 3.0σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# ════════════════════════════════════════════
# STRATEGY 2: P&L STOP-LOSS
# Exit if cumulative trade loss > X% of capital
# ════════════════════════════════════════════
&p "╠════════════════════════════════════════════════════════════════════════════════╣"

# --- PnL stop 5% ---
MaxLoss  ← × 0.05 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ PnL stop 5%              | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- PnL stop 10% ---
MaxLoss  ← × 0.10 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ PnL stop 10%             | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- PnL stop 15% ---
MaxLoss  ← × 0.15 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ PnL stop 15%             | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- PnL stop 20% ---
MaxLoss  ← × 0.20 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ PnL stop 20%             | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- PnL stop 30% ---
MaxLoss  ← × 0.30 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ PnL stop 30%             | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# ════════════════════════════════════════════
# STRATEGY 3: EQUITY DRAWDOWN BREAKER
# Go flat if portfolio DD exceeds threshold
# ════════════════════════════════════════════
&p "╠════════════════════════════════════════════════════════════════════════════════╣"

# --- DD breaker 10% ---
StopMask ← × ≠ 0 Pos > 0.10 DDAligned
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ DD breaker 10%           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- DD breaker 15% ---
StopMask ← × ≠ 0 Pos > 0.15 DDAligned
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ DD breaker 15%           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- DD breaker 20% ---
StopMask ← × ≠ 0 Pos > 0.20 DDAligned
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ DD breaker 20%           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- DD breaker 25% ---
StopMask ← × ≠ 0 Pos > 0.25 DDAligned
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ DD breaker 25%           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- DD breaker 30% ---
StopMask ← × ≠ 0 Pos > 0.30 DDAligned
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ DD breaker 30%           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# ════════════════════════════════════════════
# STRATEGY 4: TRAILING STOP
# Exit if ratio moves > Xσ away from best point since entry
# ════════════════════════════════════════════
&p "╠════════════════════════════════════════════════════════════════════════════════╣"

# --- Trail stop 0.25σ ---
TrailDist ← - RunMinDist DistFromMean
StopMask  ← × ≠ 0 Pos > × 0.25 MRSt TrailDist
StopRows  ← ≡⊟ BaseFlat StopMask
Blocked   ← ∧(. UpdatePos) StopRows 0
ModPos    ← × Pos ¬ Blocked
PfR       ← ↘ ¯1 ModPos
DPnl      ← × PfR × LegAlloc - WtiR NgR
Eqt       ← + StartingCapital \+ DPnl
Yrs       ← ÷ 252 ⧻ DPnl
TotRet    ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet    ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk        ← \↥ Eqt
MaxDd     ← × 100 /↥ ÷ Pk - Eqt Pk
DRet      ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh        ← × √252 ÷ Std DRet Mean DRet
NT        ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos     ← ≠ 0 ↘ ¯1 ModPos
APnl      ← ▽ InPos DPnl
GP        ← /+ ▽ > 0 APnl APnl
GL        ← /+ ▽ < 0 APnl APnl
PF        ← ÷ ⌵ GL GP
&pf "║ Trail stop 0.25σ         | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Trail stop 0.5σ ---
StopMask ← × ≠ 0 Pos > × 0.5 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Trail stop 0.5σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Trail stop 0.75σ ---
StopMask ← × ≠ 0 Pos > × 0.75 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Trail stop 0.75σ         | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Trail stop 1.0σ ---
StopMask ← × ≠ 0 Pos > × 1.0 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Trail stop 1.0σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

# --- Trail stop 1.5σ ---
StopMask ← × ≠ 0 Pos > × 1.5 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
Yrs      ← ÷ 252 ⧻ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
NT       ← /+ × = 0 ↘ ¯1 ModPos ≠ 0 ↘ 1 ModPos
InPos    ← ≠ 0 ↘ ¯1 ModPos
APnl     ← ▽ InPos DPnl
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP
&pf "║ Trail stop 1.5σ          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json NT
&pf " | "
&p json Rnd PF

&p "╚════════════════════════════════════════════════════════════════════════════════╝"
