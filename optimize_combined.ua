# Experimental!
# optimize_combined.ua — 2D sweep: momentum window × stop-loss strategy
# Tests top 3 stops (trail 1.0σ, ratio 3.0σ, PnL 5%) across momentum windows 1-3 days

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

FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)

CumResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(+|⊙◌)
)

MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)

# ============================================
# SHARED: Rolling stats (computed once)
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

&p ""
&p "╔═════════════════════════════════════════════════════════════════════════════════╗"
&p "║            COMBINED: MOMENTUM WINDOW × STOP-LOSS SWEEP                       ║"
&p "╠═════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                  | Sharpe | MaxDD% | AnnRet% | TotRet% | #Tr | PF    ║"
&p "╠═════════════════════════════════════════════════════════════════════════════════╣"

# ════════════════════════════════════════════════════════════════════════
# WINDOW 1: 1-DAY MOMENTUM
# ════════════════════════════════════════════════════════════════════════
RatioChg ← - ↘ ¯1 TrimmedRatio ↘ 1 TrimmedRatio
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrimmedRatio
MR       ← ↘ MomDrop TrimmedRatio
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
Pos        ← ∧(. UpdatePos) SignalRows 0

NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

BaseFlat ← = 0 Pos
PrPe     ← ⊂ 0 ↘ ¯1 Pos
EntryDay ← × = 0 PrPe ≠ 0 Pos

EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR

BasePfR     ← ↘ ¯1 Pos
BaseDPnl    ← × BasePfR × LegAlloc - WtiR NgR
DPnlAligned ← ⊂ 0 BaseDPnl
CumPnlRows  ← ≡⊟ EntryDay DPnlAligned
CumTradePnl ← ∧(. CumResetFn) CumPnlRows 0

DistFromMean ← ⌵ - MRMn MR
MinDistRows  ← ≡⊟ EntryDay DistFromMean
RunMinDist   ← ∧(. MinResetFn) MinDistRows ∞
TrailDist    ← - RunMinDist DistFromMean

# --- 1d mom, no stop ---
PfR    ← ↘ ¯1 Pos
DPnl   ← × PfR × LegAlloc - WtiR NgR
Eqt    ← + StartingCapital \+ DPnl
TotRet ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk     ← \↥ Eqt
MaxDd  ← × 100 /↥ ÷ Pk - Eqt Pk
DRet   ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh     ← × √252 ÷ Std DRet Mean DRet
NT     ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos  ← ≠ 0 ↘ ¯1 Pos
APnl   ← ▽ InPos DPnl
GP     ← /+ ▽ > 0 APnl APnl
GL     ← /+ ▽ < 0 APnl APnl
PF     ← ÷ ⌵ GL GP
ShA    ← Sh
DdA    ← MaxDd
&pf "║ 1d mom, no stop          | "
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

# --- 1d mom, trail 1.0σ ---
StopMask ← × ≠ 0 Pos > × 1.0 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShB      ← Sh
DdB      ← MaxDd
&pf "║ 1d mom, trail 1.0σ       | "
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

# --- 1d mom, ratio 3.0σ ---
StopMask ← × ≠ 0 Pos > × 3.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShC      ← Sh
DdC      ← MaxDd
&pf "║ 1d mom, ratio 3.0σ       | "
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

# --- 1d mom, PnL 5% ---
MaxLoss  ← × 0.05 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShD      ← Sh
DdD      ← MaxDd
&pf "║ 1d mom, PnL 5%           | "
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

&p "╠═════════════════════════════════════════════════════════════════════════════════╣"

# ════════════════════════════════════════════════════════════════════════
# WINDOW 2: 2-DAY MOMENTUM (current main.ua)
# ════════════════════════════════════════════════════════════════════════
RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrimmedRatio
MR       ← ↘ MomDrop TrimmedRatio
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
Pos        ← ∧(. UpdatePos) SignalRows 0

NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

BaseFlat ← = 0 Pos
PrPe     ← ⊂ 0 ↘ ¯1 Pos
EntryDay ← × = 0 PrPe ≠ 0 Pos

EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR

BasePfR     ← ↘ ¯1 Pos
BaseDPnl    ← × BasePfR × LegAlloc - WtiR NgR
DPnlAligned ← ⊂ 0 BaseDPnl
CumPnlRows  ← ≡⊟ EntryDay DPnlAligned
CumTradePnl ← ∧(. CumResetFn) CumPnlRows 0

DistFromMean ← ⌵ - MRMn MR
MinDistRows  ← ≡⊟ EntryDay DistFromMean
RunMinDist   ← ∧(. MinResetFn) MinDistRows ∞
TrailDist    ← - RunMinDist DistFromMean

# --- 2d mom, no stop ---
PfR    ← ↘ ¯1 Pos
DPnl   ← × PfR × LegAlloc - WtiR NgR
Eqt    ← + StartingCapital \+ DPnl
TotRet ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk     ← \↥ Eqt
MaxDd  ← × 100 /↥ ÷ Pk - Eqt Pk
DRet   ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh     ← × √252 ÷ Std DRet Mean DRet
NT     ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos  ← ≠ 0 ↘ ¯1 Pos
APnl   ← ▽ InPos DPnl
GP     ← /+ ▽ > 0 APnl APnl
GL     ← /+ ▽ < 0 APnl APnl
PF     ← ÷ ⌵ GL GP
ShE    ← Sh
DdE    ← MaxDd
&pf "║ 2d mom, no stop          | "
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

# --- 2d mom, trail 1.0σ ---
StopMask ← × ≠ 0 Pos > × 1.0 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShF      ← Sh
DdF      ← MaxDd
&pf "║ 2d mom, trail 1.0σ       | "
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

# --- 2d mom, ratio 3.0σ ---
StopMask ← × ≠ 0 Pos > × 3.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShG      ← Sh
DdG      ← MaxDd
&pf "║ 2d mom, ratio 3.0σ       | "
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

# --- 2d mom, PnL 5% ---
MaxLoss  ← × 0.05 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShH      ← Sh
DdH      ← MaxDd
&pf "║ 2d mom, PnL 5%           | "
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

&p "╠═════════════════════════════════════════════════════════════════════════════════╣"

# ════════════════════════════════════════════════════════════════════════
# WINDOW 3: 3-DAY MOMENTUM
# ════════════════════════════════════════════════════════════════════════
RatioChg ← - ↘ ¯3 TrimmedRatio ↘ 3 TrimmedRatio
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrimmedRatio
MR       ← ↘ MomDrop TrimmedRatio
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
Pos        ← ∧(. UpdatePos) SignalRows 0

NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

BaseFlat ← = 0 Pos
PrPe     ← ⊂ 0 ↘ ¯1 Pos
EntryDay ← × = 0 PrPe ≠ 0 Pos

EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR

BasePfR     ← ↘ ¯1 Pos
BaseDPnl    ← × BasePfR × LegAlloc - WtiR NgR
DPnlAligned ← ⊂ 0 BaseDPnl
CumPnlRows  ← ≡⊟ EntryDay DPnlAligned
CumTradePnl ← ∧(. CumResetFn) CumPnlRows 0

DistFromMean ← ⌵ - MRMn MR
MinDistRows  ← ≡⊟ EntryDay DistFromMean
RunMinDist   ← ∧(. MinResetFn) MinDistRows ∞
TrailDist    ← - RunMinDist DistFromMean

# --- 3d mom, no stop ---
PfR    ← ↘ ¯1 Pos
DPnl   ← × PfR × LegAlloc - WtiR NgR
Eqt    ← + StartingCapital \+ DPnl
TotRet ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk     ← \↥ Eqt
MaxDd  ← × 100 /↥ ÷ Pk - Eqt Pk
DRet   ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh     ← × √252 ÷ Std DRet Mean DRet
NT     ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos  ← ≠ 0 ↘ ¯1 Pos
APnl   ← ▽ InPos DPnl
GP     ← /+ ▽ > 0 APnl APnl
GL     ← /+ ▽ < 0 APnl APnl
PF     ← ÷ ⌵ GL GP
ShI    ← Sh
DdI    ← MaxDd
&pf "║ 3d mom, no stop          | "
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

# --- 3d mom, trail 1.0σ ---
StopMask ← × ≠ 0 Pos > × 1.0 MRSt TrailDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShJ      ← Sh
DdJ      ← MaxDd
&pf "║ 3d mom, trail 1.0σ       | "
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

# --- 3d mom, ratio 3.0σ ---
StopMask ← × ≠ 0 Pos > × 3.0 MRSt RatioDist
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShK      ← Sh
DdK      ← MaxDd
&pf "║ 3d mom, ratio 3.0σ       | "
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

# --- 3d mom, PnL 5% ---
MaxLoss  ← × 0.05 StartingCapital
StopMask ← × ≠ 0 Pos < ¯ MaxLoss CumTradePnl
StopRows ← ≡⊟ BaseFlat StopMask
Blocked  ← ∧(. UpdatePos) StopRows 0
ModPos   ← × Pos ¬ Blocked
PfR      ← ↘ ¯1 ModPos
DPnl     ← × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
TotRet   ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet   ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
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
ShL      ← Sh
DdL      ← MaxDd
&pf "║ 3d mom, PnL 5%           | "
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

&p "╚═════════════════════════════════════════════════════════════════════════════════╝"

# ════════════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════════════
AllSh ← [ShA ShB ShC ShD ShE ShF ShG ShH ShI ShJ ShK ShL]
AllDd ← [DdA DdB DdC DdD DdE DdF DdG DdH DdI DdJ DdK DdL]
Names ← {"1d/none" "1d/trail" "1d/ratio" "1d/pnl" "2d/none" "2d/trail" "2d/ratio" "2d/pnl" "3d/none" "3d/trail" "3d/ratio" "3d/pnl"}

BestShIdx ← ˜⨂ /↥ . AllSh
BestDdIdx ← ˜⨂ /↧ . AllDd

&p ""
&p ⊂ "Best Sharpe:  " ⊂ json Rnd ⊡ BestShIdx AllSh ⊂ " — " °□ ⊡ BestShIdx Names
&p ⊂ "Lowest MaxDD: " ⊂ json Rnd ⊡ BestDdIdx AllDd ⊂ "% — " °□ ⊡ BestDdIdx Names
