# Experimental!
# optimize_momentum.ua — Momentum window sweep (1-10 days)
# Find optimal momentum filter duration for Sharpe and MaxDD

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

# ============================================
# SHARED: Rolling stats (60-day lookback, 2σ threshold)
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

# ============================================
# HEADER
# ============================================
&p ""
&p "╔═══════════════════════════════════════════════════════════════════════════╗"
&p "║              MOMENTUM WINDOW SWEEP (1-10 days)                         ║"
&p "╠═══════════════════════════════════════════════════════════════════════════╣"
&p "║ Window | Sharpe | MaxDD% | AnnRet% | TotRet% | #Trades | AvgDur | PF  ║"
&p "╠═══════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MOM 1D ═══════════════
RatioChg   ← - ↘ ¯1 TrimmedRatio ↘ 1 TrimmedRatio
MR         ← ↘ 1 TrimmedRatio
MNg        ← ↘ 1 TrimmedNg
MWti       ← ↘ 1 TrimmedWti
MUB        ← ↘ 1 UpperBand
MLB        ← ↘ 1 LowerBand
MRMn       ← ↘ 1 RMean
MRSt       ← ↘ 1 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShA        ← Sh
DdA        ← MaxDd
&pf "║  1 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 2D ═══════════════
RatioChg   ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MR         ← ↘ 2 TrimmedRatio
MNg        ← ↘ 2 TrimmedNg
MWti       ← ↘ 2 TrimmedWti
MUB        ← ↘ 2 UpperBand
MLB        ← ↘ 2 LowerBand
MRMn       ← ↘ 2 RMean
MRSt       ← ↘ 2 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShB        ← Sh
DdB        ← MaxDd
&pf "║  2 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 3D ═══════════════
RatioChg   ← - ↘ ¯3 TrimmedRatio ↘ 3 TrimmedRatio
MR         ← ↘ 3 TrimmedRatio
MNg        ← ↘ 3 TrimmedNg
MWti       ← ↘ 3 TrimmedWti
MUB        ← ↘ 3 UpperBand
MLB        ← ↘ 3 LowerBand
MRMn       ← ↘ 3 RMean
MRSt       ← ↘ 3 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShC        ← Sh
DdC        ← MaxDd
&pf "║  3 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 4D ═══════════════
RatioChg   ← - ↘ ¯4 TrimmedRatio ↘ 4 TrimmedRatio
MR         ← ↘ 4 TrimmedRatio
MNg        ← ↘ 4 TrimmedNg
MWti       ← ↘ 4 TrimmedWti
MUB        ← ↘ 4 UpperBand
MLB        ← ↘ 4 LowerBand
MRMn       ← ↘ 4 RMean
MRSt       ← ↘ 4 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShD        ← Sh
DdD        ← MaxDd
&pf "║  4 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 5D ═══════════════
RatioChg   ← - ↘ ¯5 TrimmedRatio ↘ 5 TrimmedRatio
MR         ← ↘ 5 TrimmedRatio
MNg        ← ↘ 5 TrimmedNg
MWti       ← ↘ 5 TrimmedWti
MUB        ← ↘ 5 UpperBand
MLB        ← ↘ 5 LowerBand
MRMn       ← ↘ 5 RMean
MRSt       ← ↘ 5 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShE        ← Sh
DdE        ← MaxDd
&pf "║  5 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 6D ═══════════════
RatioChg   ← - ↘ ¯6 TrimmedRatio ↘ 6 TrimmedRatio
MR         ← ↘ 6 TrimmedRatio
MNg        ← ↘ 6 TrimmedNg
MWti       ← ↘ 6 TrimmedWti
MUB        ← ↘ 6 UpperBand
MLB        ← ↘ 6 LowerBand
MRMn       ← ↘ 6 RMean
MRSt       ← ↘ 6 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShF        ← Sh
DdF        ← MaxDd
&pf "║  6 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 7D ═══════════════
RatioChg   ← - ↘ ¯7 TrimmedRatio ↘ 7 TrimmedRatio
MR         ← ↘ 7 TrimmedRatio
MNg        ← ↘ 7 TrimmedNg
MWti       ← ↘ 7 TrimmedWti
MUB        ← ↘ 7 UpperBand
MLB        ← ↘ 7 LowerBand
MRMn       ← ↘ 7 RMean
MRSt       ← ↘ 7 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShG        ← Sh
DdG        ← MaxDd
&pf "║  7 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 8D ═══════════════
RatioChg   ← - ↘ ¯8 TrimmedRatio ↘ 8 TrimmedRatio
MR         ← ↘ 8 TrimmedRatio
MNg        ← ↘ 8 TrimmedNg
MWti       ← ↘ 8 TrimmedWti
MUB        ← ↘ 8 UpperBand
MLB        ← ↘ 8 LowerBand
MRMn       ← ↘ 8 RMean
MRSt       ← ↘ 8 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShH        ← Sh
DdH        ← MaxDd
&pf "║  8 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 9D ═══════════════
RatioChg   ← - ↘ ¯9 TrimmedRatio ↘ 9 TrimmedRatio
MR         ← ↘ 9 TrimmedRatio
MNg        ← ↘ 9 TrimmedNg
MWti       ← ↘ 9 TrimmedWti
MUB        ← ↘ 9 UpperBand
MLB        ← ↘ 9 LowerBand
MRMn       ← ↘ 9 RMean
MRSt       ← ↘ 9 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShI        ← Sh
DdI        ← MaxDd
&pf "║  9 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ═══════════════ MOM 10D ═══════════════
RatioChg   ← - ↘ ¯10 TrimmedRatio ↘ 10 TrimmedRatio
MR         ← ↘ 10 TrimmedRatio
MNg        ← ↘ 10 TrimmedNg
MWti       ← ↘ 10 TrimmedWti
MUB        ← ↘ 10 UpperBand
MLB        ← ↘ 10 LowerBand
MRMn       ← ↘ 10 RMean
MRSt       ← ↘ 10 RStd
RawLong    ← × < 0 RatioChg > MUB MR
RawShort   ← × > 0 RatioChg < MLB MR
RawEntry   ← - RawShort RawLong
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
NgR        ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR       ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
Yrs        ← ÷ 252 ⧻ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
PrP        ← ↘ ¯1 Pos
CuP        ← ↘ 1 Pos
NT         ← /+ × = 0 PrP ≠ 0 CuP
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
AvgDur     ← ÷ NT /+ ≠ 0 Pos
ShJ        ← Sh
DdJ        ← MaxDd
&pf "║ 10 day | "
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
&pf json Rnd AvgDur
&pf " | "
&p json Rnd PF

# ============================================
# SUMMARY: Find optimal window
# ============================================
&p "╠═══════════════════════════════════════════════════════════════════════════╣"

AllSh ← [ShA ShB ShC ShD ShE ShF ShG ShH ShI ShJ]
AllDd ← [DdA DdB DdC DdD DdE DdF DdG DdH DdI DdJ]

BestShIdx ← ˜⨂ /↥ . AllSh
BestDdIdx ← ˜⨂ /↧ . AllDd

&pf "║ Best Sharpe:   window = "
&pf json + 1 BestShIdx
&pf "d  (Sharpe = "
&pf json Rnd ⊡ BestShIdx AllSh
&p ")"

&pf "║ Lowest MaxDD:  window = "
&pf json + 1 BestDdIdx
&pf "d  (MaxDD = "
&pf json Rnd ⊡ BestDdIdx AllDd
&p "%)"

&p "╚═══════════════════════════════════════════════════════════════════════════╝"
