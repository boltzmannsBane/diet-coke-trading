# optimize_trend.ua — Macro trend filter variants
# Tests whether adding a long-term trend filter improves Variant G
# Base: NG>$3.50 entry filter + double stop-loss (trail 1.0σ + ratio 3.0σ)
#
# Hypothesis: during structural regime shifts (e.g. 2005-2009 shale revolution),
# a macro trend filter could prevent the strategy from fighting a permanent move.
# Trend filters tested:
#   A. 252d MA declining (20d smoothed slope ≤ 0)
#   B. Ratio below 252d MA
#   C. Ratio below 200d MA
#   D. 60d rolling mean drift ≤ 0 (20d change)
#   E. Baseline (VarG, no trend filter, same period)

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

Ratio ← ÷ AlignedNg AlignedWti

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

FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)
MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)

ExtractYear ← ⋕ ↙4 °□

# ============================================
# BASE STRATEGY ARRAYS (pre-trend-filter)
# ============================================
Lb  ← 60
Thr ← 2.0

RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrDt  ← ↘ Off AlignedDates
TrNg  ← ↘ Off AlignedNg
TrWti ← ↘ Off AlignedWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt

# 2-day momentum
RatioChg ← - ↘ ¯2 TrR ↘ 2 TrR
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrR
MR       ← ↘ MomDrop TrR
MDates   ← ↘ MomDrop TrDt
MNg      ← ↘ MomDrop TrNg
MWti     ← ↘ MomDrop TrWti
MUB      ← ↘ MomDrop UB
MLB      ← ↘ MomDrop LBand
MRMn     ← ↘ MomDrop RMn
MRSt     ← ↘ MomDrop RSt

# ============================================
# TREND INDICATORS (computed on full arrays)
# ============================================
# MR starts at Ratio index 61 (= 59 + 2)

# 252-day MA of ratio
MAlong ← ⧈(Mean) 252 Ratio
# MAlong[i] corresponds to Ratio[i+251]
# 20-day change of 252d MA (positive = rising trend)
MADiffL ← - ↘ ¯20 MAlong ↘ 20 MAlong
# MADiffL[i] corresponds to Ratio[i+271]

# 200-day MA of ratio
MAmid ← ⧈(Mean) 200 Ratio
# MAmid[i] corresponds to Ratio[i+199]

# 20-day change of 60d rolling mean (drift detector)
MnDrift ← - ↘ ¯20 RMn ↘ 20 RMn
# MnDrift[i] corresponds to Ratio[i+79]

# ============================================
# ALIGNMENT: trim everything to match MADiffL
# MADiffL starts at Ratio[271], MR at Ratio[61]
# TrendDrop = 271 - 61 = 210
# ============================================
TrendDrop ← 210

tMR    ← ↘ TrendDrop MR
tDates ← ↘ TrendDrop MDates
tNg    ← ↘ TrendDrop MNg
tWti   ← ↘ TrendDrop MWti
tUB    ← ↘ TrendDrop MUB
tLB    ← ↘ TrendDrop MLB
tRMn   ← ↘ TrendDrop MRMn
tRSt   ← ↘ TrendDrop MRSt
tRChg  ← ↘ TrendDrop RatioChg

# Align trend indicators to tMR (all length 6997)
tMAlong  ← ↘ 20 MAlong   # drop 20 to align with tMR
tMAmid   ← ↘ 72 MAmid    # drop 72 to align
tMADiff  ← MADiffL       # already aligned
tMnDrift ← ↘ 192 MnDrift # drop 192 to align

# ============================================
# HEADER
# ============================================
&p ""
&p "╔═══════════════════════════════════════════════════════════════════════════════════════════╗"
&p "║                    MACRO TREND FILTER OPTIMIZATION RESULTS                               ║"
&p "║  Base: Variant G (2d momentum + NG>$3.50 + trail 1.0σ + ratio 3.0σ)                     ║"
&p "╠═══════════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                 | Sharpe | MaxDD% | AnnRet | TotRet  | #Tr | ShPost10 | DDPost10 ║"
&p "╠═══════════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ A: 252d MA DECLINING (20d slope ≤ 0) ═══════════════
# Only enter when the 1-year trend is flat or declining (favorable for long NG)
MaskA ← ≤ 0 tMADiff
RL    ← × MaskA × > 3.5 tNg × < 0 tRChg > tUB tMR
RS    ← × MaskA × > 0 tRChg < tLB tMR
RE    ← - RS RL
NM    ← < × 0.5 tRSt ⌵ - tRMn tMR
SR    ← ≡⊟ NM RE
Pos   ← ∧(. UpdatePos) SR 0
# Double stop-loss
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - tRMn tMR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 tRSt TrailDist
EntryVal    ← × EntryDay tMR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios tMR
RatioStop   ← × ≠ 0 Pos > × 3.0 tRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
# Metrics
NgR     ← ÷ ↘ ¯1 tNg - ↘ ¯1 tNg ↘ 1 tNg
WtiR    ← ÷ ↘ ¯1 tWti - ↘ ¯1 tWti ↘ 1 tWti
PfR     ← ↘ ¯1 ModPos
DPnl    ← × PfR × LegAlloc - WtiR NgR
Eqt     ← + StartingCapital \+ DPnl
FinalEq ← ⊣ Eqt
Nn      ← ⧻ DPnl
Yrs     ← ÷ 252 Nn
TotRet  ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet  ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk      ← \↥ Eqt
MaxDd   ← × 100 /↥ ÷ Pk - Eqt Pk
DRet    ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh      ← × √252 ÷ Std DRet Mean DRet
PrP     ← ↘ ¯1 ModPos
CuP     ← ↘ 1 ModPos
NT      ← /+ × = 0 PrP ≠ 0 CuP
# Post-2010
EqDates  ← ↘ 1 tDates
YearsArr ← ≡ExtractYear EqDates
IdxPost  ← /+ < 2010 YearsArr
EqPost   ← ↘ IdxPost Eqt
EqSPost  ← ⊡ 0 EqPost
DRPost   ← ÷ ↘ ¯1 EqPost - ↘ ¯1 EqPost ↘ 1 EqPost
ShPost   ← × √252 ÷ Std DRPost Mean DRPost
PkPost   ← \↥ EqPost
DdPost   ← × 100 /↥ ÷ PkPost - EqPost PkPost

&pf "║ A: 252d MA declining    | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json ⁅ NT
&pf " | "
&pf json Rnd ShPost
&pf "   | "
&p json Rnd DdPost

# ═══════════════ B: RATIO < 252d MA ═══════════════
# Only enter when ratio is below its 1-year average
MaskB       ← < tMAlong tMR
RL          ← × MaskB × > 3.5 tNg × < 0 tRChg > tUB tMR
RS          ← × MaskB × > 0 tRChg < tLB tMR
RE          ← - RS RL
NM          ← < × 0.5 tRSt ⌵ - tRMn tMR
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - tRMn tMR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 tRSt TrailDist
EntryVal    ← × EntryDay tMR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios tMR
RatioStop   ← × ≠ 0 Pos > × 3.0 tRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 tNg - ↘ ¯1 tNg ↘ 1 tNg
WtiR        ← ÷ ↘ ¯1 tWti - ↘ ¯1 tWti ↘ 1 tWti
PfR         ← ↘ ¯1 ModPos
DPnl        ← × PfR × LegAlloc - WtiR NgR
Eqt         ← + StartingCapital \+ DPnl
FinalEq     ← ⊣ Eqt
Nn          ← ⧻ DPnl
Yrs         ← ÷ 252 Nn
TotRet      ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet      ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk          ← \↥ Eqt
MaxDd       ← × 100 /↥ ÷ Pk - Eqt Pk
DRet        ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh          ← × √252 ÷ Std DRet Mean DRet
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
EqPost      ← ↘ IdxPost Eqt
EqSPost     ← ⊡ 0 EqPost
DRPost      ← ÷ ↘ ¯1 EqPost - ↘ ¯1 EqPost ↘ 1 EqPost
ShPost      ← × √252 ÷ Std DRPost Mean DRPost
PkPost      ← \↥ EqPost
DdPost      ← × 100 /↥ ÷ PkPost - EqPost PkPost

&pf "║ B: Ratio < 252d MA      | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json ⁅ NT
&pf " | "
&pf json Rnd ShPost
&pf "   | "
&p json Rnd DdPost

# ═══════════════ C: RATIO < 200d MA ═══════════════
# Only enter when ratio is below its 200-day average
MaskC       ← < tMAmid tMR
RL          ← × MaskC × > 3.5 tNg × < 0 tRChg > tUB tMR
RS          ← × MaskC × > 0 tRChg < tLB tMR
RE          ← - RS RL
NM          ← < × 0.5 tRSt ⌵ - tRMn tMR
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - tRMn tMR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 tRSt TrailDist
EntryVal    ← × EntryDay tMR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios tMR
RatioStop   ← × ≠ 0 Pos > × 3.0 tRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 tNg - ↘ ¯1 tNg ↘ 1 tNg
WtiR        ← ÷ ↘ ¯1 tWti - ↘ ¯1 tWti ↘ 1 tWti
PfR         ← ↘ ¯1 ModPos
DPnl        ← × PfR × LegAlloc - WtiR NgR
Eqt         ← + StartingCapital \+ DPnl
FinalEq     ← ⊣ Eqt
Nn          ← ⧻ DPnl
Yrs         ← ÷ 252 Nn
TotRet      ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet      ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk          ← \↥ Eqt
MaxDd       ← × 100 /↥ ÷ Pk - Eqt Pk
DRet        ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh          ← × √252 ÷ Std DRet Mean DRet
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
EqPost      ← ↘ IdxPost Eqt
EqSPost     ← ⊡ 0 EqPost
DRPost      ← ÷ ↘ ¯1 EqPost - ↘ ¯1 EqPost ↘ 1 EqPost
ShPost      ← × √252 ÷ Std DRPost Mean DRPost
PkPost      ← \↥ EqPost
DdPost      ← × 100 /↥ ÷ PkPost - EqPost PkPost

&pf "║ C: Ratio < 200d MA      | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json ⁅ NT
&pf " | "
&pf json Rnd ShPost
&pf "   | "
&p json Rnd DdPost

# ═══════════════ D: 60d MEAN DRIFT ≤ 0 ═══════════════
# Only enter when the 60d rolling mean has been declining over 20 days
# Catches structural shifts where the "normal" ratio level is rising
MaskD       ← ≤ 0 tMnDrift
RL          ← × MaskD × > 3.5 tNg × < 0 tRChg > tUB tMR
RS          ← × MaskD × > 0 tRChg < tLB tMR
RE          ← - RS RL
NM          ← < × 0.5 tRSt ⌵ - tRMn tMR
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - tRMn tMR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 tRSt TrailDist
EntryVal    ← × EntryDay tMR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios tMR
RatioStop   ← × ≠ 0 Pos > × 3.0 tRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 tNg - ↘ ¯1 tNg ↘ 1 tNg
WtiR        ← ÷ ↘ ¯1 tWti - ↘ ¯1 tWti ↘ 1 tWti
PfR         ← ↘ ¯1 ModPos
DPnl        ← × PfR × LegAlloc - WtiR NgR
Eqt         ← + StartingCapital \+ DPnl
FinalEq     ← ⊣ Eqt
Nn          ← ⧻ DPnl
Yrs         ← ÷ 252 Nn
TotRet      ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet      ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk          ← \↥ Eqt
MaxDd       ← × 100 /↥ ÷ Pk - Eqt Pk
DRet        ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh          ← × √252 ÷ Std DRet Mean DRet
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
EqPost      ← ↘ IdxPost Eqt
EqSPost     ← ⊡ 0 EqPost
DRPost      ← ÷ ↘ ¯1 EqPost - ↘ ¯1 EqPost ↘ 1 EqPost
ShPost      ← × √252 ÷ Std DRPost Mean DRPost
PkPost      ← \↥ EqPost
DdPost      ← × 100 /↥ ÷ PkPost - EqPost PkPost

&pf "║ D: Mean drift ≤ 0       | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json ⁅ NT
&pf " | "
&pf json Rnd ShPost
&pf "   | "
&p json Rnd DdPost

# ═══════════════ E: BASELINE (VarG, no trend filter) ═══════════════
RL          ← × > 3.5 tNg × < 0 tRChg > tUB tMR
RS          ← × > 0 tRChg < tLB tMR
RE          ← - RS RL
NM          ← < × 0.5 tRSt ⌵ - tRMn tMR
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - tRMn tMR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 tRSt TrailDist
EntryVal    ← × EntryDay tMR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios tMR
RatioStop   ← × ≠ 0 Pos > × 3.0 tRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 tNg - ↘ ¯1 tNg ↘ 1 tNg
WtiR        ← ÷ ↘ ¯1 tWti - ↘ ¯1 tWti ↘ 1 tWti
PfR         ← ↘ ¯1 ModPos
DPnl        ← × PfR × LegAlloc - WtiR NgR
Eqt         ← + StartingCapital \+ DPnl
FinalEq     ← ⊣ Eqt
Nn          ← ⧻ DPnl
Yrs         ← ÷ 252 Nn
TotRet      ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet      ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk          ← \↥ Eqt
MaxDd       ← × 100 /↥ ÷ Pk - Eqt Pk
DRet        ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh          ← × √252 ÷ Std DRet Mean DRet
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
EqPost      ← ↘ IdxPost Eqt
EqSPost     ← ⊡ 0 EqPost
DRPost      ← ÷ ↘ ¯1 EqPost - ↘ ¯1 EqPost ↘ 1 EqPost
ShPost      ← × √252 ÷ Std DRPost Mean DRPost
PkPost      ← \↥ EqPost
DdPost      ← × 100 /↥ ÷ PkPost - EqPost PkPost

&pf "║ E: Baseline (VarG) ★    | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json ⁅ NT
&pf " | "
&pf json Rnd ShPost
&pf "   | "
&p json Rnd DdPost

&p "╠═══════════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ ShPost10 = post-2010 Sharpe.  DDPost10 = post-2010 MaxDD%.                              ║"
&p "║ ★ = current main.ua strategy (slightly shorter period due to 252d MA alignment)          ║"
&p "║                                                                                          ║"
&p "║ Filters tested:                                                                          ║"
&p "║   A: Only enter when 252d MA of ratio has declined over past 20 days                     ║"
&p "║   B: Only enter when ratio is below its 252d MA                                          ║"
&p "║   C: Only enter when ratio is below its 200d MA                                          ║"
&p "║   D: Only enter when 60d rolling mean has declined over past 20 days                     ║"
&p "╚═══════════════════════════════════════════════════════════════════════════════════════════╝"
