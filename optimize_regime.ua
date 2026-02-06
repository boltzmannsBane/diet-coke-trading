# optimize_regime.ua — Coal switching regime filter + heating oil seasonal
# Tests whether fundamental price-level filters improve signal quality

# ============================================
# Shared data loading & strategy base
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

# Load heating oil
ParseCsv "data/ho_daily.csv"
HoDates  ←
HoPrices ←

NgInWti      ← ∊ WtiDates NgDates
AlignedDates ← ▽ NgInWti NgDates
AlignedNg    ← ▽ NgInWti NgPrices
WtiIdx       ← ⨂ WtiDates AlignedDates
AlignedWti   ← ⊏ WtiIdx WtiPrices

Mean            ← ÷⊃⧻(/+)
Std             ← √ Mean ⁿ2 - Mean .
Rnd             ← ÷ 100 ⁅ × 100
StartingCapital ← 100000
LegAlloc        ← ÷ 2 StartingCapital
Lookback        ← 60
Threshold       ← 2.0

Ratio ← ÷ AlignedNg AlignedWti
RMean ← ⧈(Mean) Lookback Ratio
RStd  ← ⧈(Std) Lookback Ratio

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

# Base signals (before regime filter)
RawLong  ← × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
NearMean ← < × 0.5 MRSt ⌵ - MRMn MR

UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

# Align heating oil to MDates
HoInM     ← ∊ HoDates MDates
MdInHo    ← ▽ HoInM MDates
HoIdxM    ← ⨂ HoDates MdInHo
HoMatched ← ⊏ HoIdxM HoPrices
# Create full-length HO array (0 for missing dates)
HoMask ← ∊ HoDates MDates
# Build aligned HO prices: for each MDate, get HO price or 0
# Use scatter approach: place matched prices at correct indices
HoFull ← ▽ HoMask HoPrices
# HoFull only has prices for matching dates — need full-length array
# Count matches vs total
&p ⊂ "HO dates matched: " ⊂ json ⧻ HoFull ⊂ " / " json ⧻ MDates

# Extract month from dates for seasonal filter
ExtractMonth ← ⋕ ↙2 ↘5 °□
Months       ← ≡ExtractMonth MDates
# Heating season: Oct-Mar (months 10,11,12,1,2,3)
IsHeating ← ↥ ≥ 10 Months ≤ 3 Months

# For HO seasonal: compute HO/NG ratio z-score on matched dates
# Since HoFull only contains matched dates, not full length,
# we need a different approach: build index mapping
# For each MDate index, find if it exists in HoDates
MdInHoMask ← ∊ HoDates MDates # length = ⧻ MDates
&p ⊂ "HO coverage: " ⊂ json Rnd × 100 ÷ ⧻ MDates /+ MdInHoMask "%"

# ============================================
# Metrics helper (compute on equity slice)
# ============================================

&p ""
&p "══════════════════════════════════════════════════════════════════════"
&p "REGIME FILTER OPTIMIZATION"
&p "══════════════════════════════════════════════════════════════════════"
&p ""
&p "Variant                    Sharpe  MaxDD%  AnnRet%  TotRet%  Trades"
&p "─────────────────────────  ──────  ──────  ───────  ───────  ──────"

# ============================================
# Variant A: Baseline (no regime filter)
# ============================================
RawEntryA ← - RawShort RawLong
SigA      ← ≡⊟ NearMean RawEntryA
PosA      ← ∧(. UpdatePos) SigA 0

NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

PfRA  ← ↘ ¯1 PosA
DpA   ← × PfRA × LegAlloc - WtiR NgR
EqA   ← + StartingCapital \+ DpA
NnA   ← ⧻ DpA
YrsA  ← ÷ 252 NnA
DRetA ← ÷ ↘ ¯1 EqA - ↘ ¯1 EqA ↘ 1 EqA
ShA   ← × √252 ÷ Std DRetA Mean DRetA
DdA   ← × 100 /↥ ÷ \↥ EqA - EqA \↥ EqA
TrA   ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqA
ArA   ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqA
PvA   ← ↘ ¯1 PosA
CvA   ← ↘ 1 PosA
TdA   ← /+ × = 0 PvA ≠ 0 CvA
&p ⊂ "Baseline (no filter)       " ⊂ json Rnd ShA ⊂ "    " ⊂ json Rnd DdA ⊂ "    " ⊂ json Rnd ArA ⊂ "      " ⊂ json Rnd TrA ⊂ "     " json TdA

# ============================================
# Variant B: Coal floor < $2.50
# ============================================
CoalB     ← < 2.5 MNg
LongB     ← × CoalB RawLong
RawEntryB ← - RawShort LongB
SigB      ← ≡⊟ NearMean RawEntryB
PosB      ← ∧(. UpdatePos) SigB 0
PfRB      ← ↘ ¯1 PosB
DpB       ← × PfRB × LegAlloc - WtiR NgR
EqB       ← + StartingCapital \+ DpB
DRetB     ← ÷ ↘ ¯1 EqB - ↘ ¯1 EqB ↘ 1 EqB
ShB       ← × √252 ÷ Std DRetB Mean DRetB
DdB       ← × 100 /↥ ÷ \↥ EqB - EqB \↥ EqB
TrB       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqB
ArB       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqB
PvB       ← ↘ ¯1 PosB
CvB       ← ↘ 1 PosB
TdB       ← /+ × = 0 PvB ≠ 0 CvB
&p ⊂ "Coal floor < $2.50         " ⊂ json Rnd ShB ⊂ "    " ⊂ json Rnd DdB ⊂ "    " ⊂ json Rnd ArB ⊂ "      " ⊂ json Rnd TrB ⊂ "     " json TdB

# ============================================
# Variant C: Coal floor < $3.00
# ============================================
CoalC     ← < 3.0 MNg
LongC     ← × CoalC RawLong
RawEntryC ← - RawShort LongC
SigC      ← ≡⊟ NearMean RawEntryC
PosC      ← ∧(. UpdatePos) SigC 0
PfRC      ← ↘ ¯1 PosC
DpC       ← × PfRC × LegAlloc - WtiR NgR
EqC       ← + StartingCapital \+ DpC
DRetC     ← ÷ ↘ ¯1 EqC - ↘ ¯1 EqC ↘ 1 EqC
ShC       ← × √252 ÷ Std DRetC Mean DRetC
DdC       ← × 100 /↥ ÷ \↥ EqC - EqC \↥ EqC
TrC       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqC
ArC       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqC
PvC       ← ↘ ¯1 PosC
CvC       ← ↘ 1 PosC
TdC       ← /+ × = 0 PvC ≠ 0 CvC
&p ⊂ "Coal floor < $3.00         " ⊂ json Rnd ShC ⊂ "    " ⊂ json Rnd DdC ⊂ "    " ⊂ json Rnd ArC ⊂ "      " ⊂ json Rnd TrC ⊂ "     " json TdC

# ============================================
# Variant D: Coal floor < $3.50
# ============================================
CoalD     ← < 3.5 MNg
LongD     ← × CoalD RawLong
RawEntryD ← - RawShort LongD
SigD      ← ≡⊟ NearMean RawEntryD
PosD      ← ∧(. UpdatePos) SigD 0
PfRD      ← ↘ ¯1 PosD
DpD       ← × PfRD × LegAlloc - WtiR NgR
EqD       ← + StartingCapital \+ DpD
DRetD     ← ÷ ↘ ¯1 EqD - ↘ ¯1 EqD ↘ 1 EqD
ShD       ← × √252 ÷ Std DRetD Mean DRetD
DdD       ← × 100 /↥ ÷ \↥ EqD - EqD \↥ EqD
TrD       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqD
ArD       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqD
PvD       ← ↘ ¯1 PosD
CvD       ← ↘ 1 PosD
TdD       ← /+ × = 0 PvD ≠ 0 CvD
&p ⊂ "Coal floor < $3.50         " ⊂ json Rnd ShD ⊂ "    " ⊂ json Rnd DdD ⊂ "    " ⊂ json Rnd ArD ⊂ "      " ⊂ json Rnd TrD ⊂ "     " json TdD

# ============================================
# Variant E: Coal floor < $4.15 (generous)
# ============================================
CoalE     ← < 4.15 MNg
LongE     ← × CoalE RawLong
RawEntryE ← - RawShort LongE
SigE      ← ≡⊟ NearMean RawEntryE
PosE      ← ∧(. UpdatePos) SigE 0
PfRE      ← ↘ ¯1 PosE
DpE       ← × PfRE × LegAlloc - WtiR NgR
EqE       ← + StartingCapital \+ DpE
DRetE     ← ÷ ↘ ¯1 EqE - ↘ ¯1 EqE ↘ 1 EqE
ShE       ← × √252 ÷ Std DRetE Mean DRetE
DdE       ← × 100 /↥ ÷ \↥ EqE - EqE \↥ EqE
TrE       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqE
ArE       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqE
PvE       ← ↘ ¯1 PosE
CvE       ← ↘ 1 PosE
TdE       ← /+ × = 0 PvE ≠ 0 CvE
&p ⊂ "Coal floor < $4.15         " ⊂ json Rnd ShE ⊂ "    " ⊂ json Rnd DdE ⊂ "    " ⊂ json Rnd ArE ⊂ "      " ⊂ json Rnd TrE ⊂ "     " json TdE

# ============================================
# Variant F: Switching zone (< $2.50 OR > $4.15)
# ============================================
SwitchF   ← ↥ < 2.5 MNg > 4.15 MNg
LongF     ← × SwitchF RawLong
ShortF    ← × (> 4.15 MNg) RawShort
RawEntryF ← - ShortF LongF
SigF      ← ≡⊟ NearMean RawEntryF
PosF      ← ∧(. UpdatePos) SigF 0
PfRF      ← ↘ ¯1 PosF
DpF       ← × PfRF × LegAlloc - WtiR NgR
EqF       ← + StartingCapital \+ DpF
DRetF     ← ÷ ↘ ¯1 EqF - ↘ ¯1 EqF ↘ 1 EqF
ShF       ← × √252 ÷ Std DRetF Mean DRetF
DdF       ← × 100 /↥ ÷ \↥ EqF - EqF \↥ EqF
TrF       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqF
ArF       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqF
PvF       ← ↘ ¯1 PosF
CvF       ← ↘ 1 PosF
TdF       ← /+ × = 0 PvF ≠ 0 CvF
&p ⊂ "Switch zone (<2.5 OR >4.15) " ⊂ json Rnd ShF ⊂ "    " ⊂ json Rnd DdF ⊂ "    " ⊂ json Rnd ArF ⊂ "      " ⊂ json Rnd TrF ⊂ "     " json TdF

# ============================================
# Variant G: Coal floor < $3.00 + heating season only
# (Only enter when NG < $3 AND month is Oct-Mar)
# ============================================
CoalG     ← × IsHeating < 3.0 MNg
LongG     ← × CoalG RawLong
RawEntryG ← - RawShort LongG
SigG      ← ≡⊟ NearMean RawEntryG
PosG      ← ∧(. UpdatePos) SigG 0
PfRG      ← ↘ ¯1 PosG
DpG       ← × PfRG × LegAlloc - WtiR NgR
EqG       ← + StartingCapital \+ DpG
DRetG     ← ÷ ↘ ¯1 EqG - ↘ ¯1 EqG ↘ 1 EqG
ShG       ← × √252 ÷ Std DRetG Mean DRetG
DdG       ← × 100 /↥ ÷ \↥ EqG - EqG \↥ EqG
TrG       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqG
ArG       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqG
PvG       ← ↘ ¯1 PosG
CvG       ← ↘ 1 PosG
TdG       ← /+ × = 0 PvG ≠ 0 CvG
&p ⊂ "Coal <3 + heating season    " ⊂ json Rnd ShG ⊂ "    " ⊂ json Rnd DdG ⊂ "    " ⊂ json Rnd ArG ⊂ "      " ⊂ json Rnd TrG ⊂ "     " json TdG

# ============================================
# Variant H: Heating season only (no coal filter)
# ============================================
LongH     ← × IsHeating RawLong
RawEntryH ← - RawShort LongH
SigH      ← ≡⊟ NearMean RawEntryH
PosH      ← ∧(. UpdatePos) SigH 0
PfRH      ← ↘ ¯1 PosH
DpH       ← × PfRH × LegAlloc - WtiR NgR
EqH       ← + StartingCapital \+ DpH
DRetH     ← ÷ ↘ ¯1 EqH - ↘ ¯1 EqH ↘ 1 EqH
ShH       ← × √252 ÷ Std DRetH Mean DRetH
DdH       ← × 100 /↥ ÷ \↥ EqH - EqH \↥ EqH
TrH       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqH
ArH       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqH
PvH       ← ↘ ¯1 PosH
CvH       ← ↘ 1 PosH
TdH       ← /+ × = 0 PvH ≠ 0 CvH
&p ⊂ "Heating season only         " ⊂ json Rnd ShH ⊂ "    " ⊂ json Rnd DdH ⊂ "    " ⊂ json Rnd ArH ⊂ "      " ⊂ json Rnd TrH ⊂ "     " json TdH

# ============================================
# Variant I: Inverse — only trade when NG > $3.50 (no floor help)
# Tests if avoiding cheap-NG entries actually hurts
# ============================================
HighI     ← > 3.5 MNg
LongI     ← × HighI RawLong
RawEntryI ← - RawShort LongI
SigI      ← ≡⊟ NearMean RawEntryI
PosI      ← ∧(. UpdatePos) SigI 0
PfRI      ← ↘ ¯1 PosI
DpI       ← × PfRI × LegAlloc - WtiR NgR
EqI       ← + StartingCapital \+ DpI
DRetI     ← ÷ ↘ ¯1 EqI - ↘ ¯1 EqI ↘ 1 EqI
ShI       ← × √252 ÷ Std DRetI Mean DRetI
DdI       ← × 100 /↥ ÷ \↥ EqI - EqI \↥ EqI
TrI       ← × 100 ÷ StartingCapital - StartingCapital ⊣ EqI
ArI       ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ EqI
PvI       ← ↘ ¯1 PosI
CvI       ← ↘ 1 PosI
TdI       ← /+ × = 0 PvI ≠ 0 CvI
&p ⊂ "Inverse: NG > $3.50 only    " ⊂ json Rnd ShI ⊂ "    " ⊂ json Rnd DdI ⊂ "    " ⊂ json Rnd ArI ⊂ "      " ⊂ json Rnd TrI ⊂ "     " json TdI

&p ""
&p "Coal switching logic: NG below threshold = coal-to-gas demand floor active."
&p "When floor is active, long NG has physical support → stronger mean reversion."
&p "Heating season = Oct-Mar (months when NG/heating oil demand overlap)."
