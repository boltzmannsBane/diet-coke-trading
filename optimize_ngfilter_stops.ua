# optimize_ngfilter_stops.ua — Combine NG > $3.50 filter with stop-losses
# Tests whether stacking the best regime filter with best stops improves Sharpe

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
# SHARED: Rolling stats + momentum + raw signals
# ============================================
Lookback  ← 60
Threshold ← 2.0

RMean        ← ⧈(Mean) Lookback Ratio
RStd         ← ⧈(Std) Lookback Ratio
Offset       ← - 1 Lookback
TrimmedRatio ← ↘ Offset Ratio
TrimmedDates ← ↘ Offset AlignedDates
TrimmedNg    ← ↘ Offset AlignedNg
TrimmedWti   ← ↘ Offset AlignedWti
UpperBand    ← + RMean × Threshold RStd
LowerBand    ← - RMean × Threshold RStd

# 2-day momentum
RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MR       ← ↘ 2 TrimmedRatio
MNg      ← ↘ 2 TrimmedNg
MWti     ← ↘ 2 TrimmedWti
MUB      ← ↘ 2 UpperBand
MLB      ← ↘ 2 LowerBand
MRMn     ← ↘ 2 RMean
MRSt     ← ↘ 2 RStd
MDts     ← ↘ 2 TrimmedDates

RawLong  ← × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
NearMean ← < × 0.5 MRSt ⌵ - MRMn MR

# Returns (shared)
NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

# For post-2010 sub-period
ExtractYear ← ⋕ ↙4 °□
EqDates     ← ↘ 1 MDts
YearsArr    ← ≡ExtractYear EqDates
IdxPost     ← /+ < 2010 YearsArr

# ============================================
# Distance from mean (shared for trail stops)
# ============================================
DistFromMean ← ⌵ - MRMn MR

&p "══════════════════════════════════════════════════════════════════════════════════"
&p "NG > $3.50 FILTER + STOP-LOSS COMBINATIONS"
&p "══════════════════════════════════════════════════════════════════════════════════"
&p ""
&p "                              ── Full Period ──   ── Post-2010 ──"
&p "Variant                       Sh   MaxDD  TotRet  Sh   MaxDD  Trades"
&p "────────────────────────────  ────  ─────  ──────  ────  ─────  ──────"

# ============================================
# A: Baseline (no filter, no stop)
# ============================================
RawEntryA ← - RawShort RawLong
SigA      ← ≡⊟ NearMean RawEntryA
PosA      ← ∧(. UpdatePos) SigA 0
PfRA      ← ↘ ¯1 PosA
DpA       ← × PfRA × LegAlloc - WtiR NgR
EqA       ← + StartingCapital \+ DpA
DRetA     ← ÷ ↘ ¯1 EqA - ↘ ¯1 EqA ↘ 1 EqA
ShA       ← Rnd × √252 ÷ Std DRetA Mean DRetA
DdA       ← Rnd × 100 /↥ ÷ \↥ EqA - EqA \↥ EqA
TrA       ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqA
# Post-2010
EqPA ← ↘ IdxPost EqA
DRPA ← ÷ ↘ ¯1 EqPA - ↘ ¯1 EqPA ↘ 1 EqPA
ShPA ← Rnd × √252 ÷ Std DRPA Mean DRPA
DdPA ← Rnd × 100 /↥ ÷ \↥ EqPA - EqPA \↥ EqPA
TdA  ← /+ × = 0 ↘ ¯1 PosA ≠ 0 ↘ 1 PosA
&p ⊂ "A: Baseline                   " ⊂ json ShA ⊂ "  " ⊂ json DdA ⊂ "  " ⊂ json TrA ⊂ "    " ⊂ json ShPA ⊂ "  " ⊂ json DdPA ⊂ "  " json TdA

# ============================================
# B: NG > $3.50 only (no stop)
# ============================================
LongB     ← × (> 3.5 MNg) RawLong
RawEntryB ← - RawShort LongB
SigB      ← ≡⊟ NearMean RawEntryB
PosB      ← ∧(. UpdatePos) SigB 0
PfRB      ← ↘ ¯1 PosB
DpB       ← × PfRB × LegAlloc - WtiR NgR
EqB       ← + StartingCapital \+ DpB
DRetB     ← ÷ ↘ ¯1 EqB - ↘ ¯1 EqB ↘ 1 EqB
ShB       ← Rnd × √252 ÷ Std DRetB Mean DRetB
DdB       ← Rnd × 100 /↥ ÷ \↥ EqB - EqB \↥ EqB
TrB       ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqB
EqPB      ← ↘ IdxPost EqB
DRPB      ← ÷ ↘ ¯1 EqPB - ↘ ¯1 EqPB ↘ 1 EqPB
ShPB      ← Rnd × √252 ÷ Std DRPB Mean DRPB
DdPB      ← Rnd × 100 /↥ ÷ \↥ EqPB - EqPB \↥ EqPB
TdB       ← /+ × = 0 ↘ ¯1 PosB ≠ 0 ↘ 1 PosB
&p ⊂ "B: NG>3.50 only               " ⊂ json ShB ⊂ "  " ⊂ json DdB ⊂ "  " ⊂ json TrB ⊂ "    " ⊂ json ShPB ⊂ "  " ⊂ json DdPB ⊂ "  " json TdB

# ============================================
# C: NG > $3.50 + Trail stop 1.0σ
# ============================================
# Reuse PosB from NG > $3.50 entry filter
BaseFlatC ← = 0 PosB
PrPeC     ← ⊂ 0 ↘ ¯1 PosB
EntryDayC ← × = 0 PrPeC ≠ 0 PosB
MinDstRC  ← ≡⊟ EntryDayC DistFromMean
RunMinC   ← ∧(. MinResetFn) MinDstRC ∞
TrailDstC ← - RunMinC DistFromMean
StopMskC  ← × ≠ 0 PosB > × 1.0 MRSt TrailDstC
StopRwC   ← ≡⊟ BaseFlatC StopMskC
BlockedC  ← ∧(. UpdatePos) StopRwC 0
ModPosC   ← × PosB ¬ BlockedC
PfRC      ← ↘ ¯1 ModPosC
DpC       ← × PfRC × LegAlloc - WtiR NgR
EqC       ← + StartingCapital \+ DpC
DRetC     ← ÷ ↘ ¯1 EqC - ↘ ¯1 EqC ↘ 1 EqC
ShC       ← Rnd × √252 ÷ Std DRetC Mean DRetC
DdC       ← Rnd × 100 /↥ ÷ \↥ EqC - EqC \↥ EqC
TrC       ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqC
EqPC      ← ↘ IdxPost EqC
DRPC      ← ÷ ↘ ¯1 EqPC - ↘ ¯1 EqPC ↘ 1 EqPC
ShPC      ← Rnd × √252 ÷ Std DRPC Mean DRPC
DdPC      ← Rnd × 100 /↥ ÷ \↥ EqPC - EqPC \↥ EqPC
TdC       ← /+ × = 0 ↘ ¯1 ModPosC ≠ 0 ↘ 1 ModPosC
&p ⊂ "C: NG>3.50 + trail 1.0σ       " ⊂ json ShC ⊂ "  " ⊂ json DdC ⊂ "  " ⊂ json TrC ⊂ "    " ⊂ json ShPC ⊂ "  " ⊂ json DdPC ⊂ "  " json TdC

# ============================================
# D: NG > $3.50 + Ratio stop 3.0σ
# ============================================
EntryValD  ← × EntryDayC MR
EntryRatD  ← FillFwd EntryValD
RatioDistD ← ⌵ - EntryRatD MR
StopMskD   ← × ≠ 0 PosB > × 3.0 MRSt RatioDistD
StopRwD    ← ≡⊟ BaseFlatC StopMskD
BlockedD   ← ∧(. UpdatePos) StopRwD 0
ModPosD    ← × PosB ¬ BlockedD
PfRD       ← ↘ ¯1 ModPosD
DpD        ← × PfRD × LegAlloc - WtiR NgR
EqD        ← + StartingCapital \+ DpD
DRetD      ← ÷ ↘ ¯1 EqD - ↘ ¯1 EqD ↘ 1 EqD
ShD        ← Rnd × √252 ÷ Std DRetD Mean DRetD
DdD        ← Rnd × 100 /↥ ÷ \↥ EqD - EqD \↥ EqD
TrD        ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqD
EqPD       ← ↘ IdxPost EqD
DRPD       ← ÷ ↘ ¯1 EqPD - ↘ ¯1 EqPD ↘ 1 EqPD
ShPD       ← Rnd × √252 ÷ Std DRPD Mean DRPD
DdPD       ← Rnd × 100 /↥ ÷ \↥ EqPD - EqPD \↥ EqPD
TdD        ← /+ × = 0 ↘ ¯1 ModPosD ≠ 0 ↘ 1 ModPosD
&p ⊂ "D: NG>3.50 + ratio 3.0σ       " ⊂ json ShD ⊂ "  " ⊂ json DdD ⊂ "  " ⊂ json TrD ⊂ "    " ⊂ json ShPD ⊂ "  " ⊂ json DdPD ⊂ "  " json TdD

# ============================================
# E: NG > $3.50 + PnL stop 5%
# ============================================
BasePfRE   ← ↘ ¯1 PosB
BaseDPnlE  ← × BasePfRE × LegAlloc - WtiR NgR
DPnlAlignE ← ⊂ 0 BaseDPnlE
CumPnlRwE  ← ≡⊟ EntryDayC DPnlAlignE
CumTrdPnlE ← ∧(. CumResetFn) CumPnlRwE 0
MaxLossE   ← × 0.05 StartingCapital
StopMskE   ← × ≠ 0 PosB < ¯ MaxLossE CumTrdPnlE
StopRwE    ← ≡⊟ BaseFlatC StopMskE
BlockedE   ← ∧(. UpdatePos) StopRwE 0
ModPosE    ← × PosB ¬ BlockedE
PfRE       ← ↘ ¯1 ModPosE
DpE        ← × PfRE × LegAlloc - WtiR NgR
EqE        ← + StartingCapital \+ DpE
DRetE      ← ÷ ↘ ¯1 EqE - ↘ ¯1 EqE ↘ 1 EqE
ShE        ← Rnd × √252 ÷ Std DRetE Mean DRetE
DdE        ← Rnd × 100 /↥ ÷ \↥ EqE - EqE \↥ EqE
TrE        ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqE
EqPE       ← ↘ IdxPost EqE
DRPE       ← ÷ ↘ ¯1 EqPE - ↘ ¯1 EqPE ↘ 1 EqPE
ShPE       ← Rnd × √252 ÷ Std DRPE Mean DRPE
DdPE       ← Rnd × 100 /↥ ÷ \↥ EqPE - EqPE \↥ EqPE
TdE        ← /+ × = 0 ↘ ¯1 ModPosE ≠ 0 ↘ 1 ModPosE
&p ⊂ "E: NG>3.50 + PnL 5%           " ⊂ json ShE ⊂ "  " ⊂ json DdE ⊂ "  " ⊂ json TrE ⊂ "    " ⊂ json ShPE ⊂ "  " ⊂ json DdPE ⊂ "  " json TdE

# ============================================
# F: Switch zone (<2.50 OR >4.15) + trail 1.0σ
# ============================================
SwitchF   ← ↥ < 2.5 MNg > 4.15 MNg
LongF     ← × SwitchF RawLong
ShortF    ← × (> 4.15 MNg) RawShort
RawEntryF ← - ShortF LongF
SigF      ← ≡⊟ NearMean RawEntryF
PosF      ← ∧(. UpdatePos) SigF 0
BaseFlatF ← = 0 PosF
PrPeF     ← ⊂ 0 ↘ ¯1 PosF
EntryDayF ← × = 0 PrPeF ≠ 0 PosF
MinDstRF  ← ≡⊟ EntryDayF DistFromMean
RunMinF   ← ∧(. MinResetFn) MinDstRF ∞
TrailDstF ← - RunMinF DistFromMean
StopMskF  ← × ≠ 0 PosF > × 1.0 MRSt TrailDstF
StopRwF   ← ≡⊟ BaseFlatF StopMskF
BlockedF  ← ∧(. UpdatePos) StopRwF 0
ModPosF   ← × PosF ¬ BlockedF
PfRF      ← ↘ ¯1 ModPosF
DpF       ← × PfRF × LegAlloc - WtiR NgR
EqF       ← + StartingCapital \+ DpF
DRetF     ← ÷ ↘ ¯1 EqF - ↘ ¯1 EqF ↘ 1 EqF
ShF       ← Rnd × √252 ÷ Std DRetF Mean DRetF
DdF       ← Rnd × 100 /↥ ÷ \↥ EqF - EqF \↥ EqF
TrF       ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqF
EqPF      ← ↘ IdxPost EqF
DRPF      ← ÷ ↘ ¯1 EqPF - ↘ ¯1 EqPF ↘ 1 EqPF
ShPF      ← Rnd × √252 ÷ Std DRPF Mean DRPF
DdPF      ← Rnd × 100 /↥ ÷ \↥ EqPF - EqPF \↥ EqPF
TdF       ← /+ × = 0 ↘ ¯1 ModPosF ≠ 0 ↘ 1 ModPosF
&p ⊂ "F: Switch zone + trail 1.0σ    " ⊂ json ShF ⊂ "  " ⊂ json DdF ⊂ "  " ⊂ json TrF ⊂ "    " ⊂ json ShPF ⊂ "  " ⊂ json DdPF ⊂ "  " json TdF

# ============================================
# G: NG > $3.50 + trail 1.0σ + ratio 3.0σ (double stop)
# ============================================
# Apply BOTH stops: exit on whichever triggers first
DblStopG ← ↥ StopMskC StopMskD
StopRwG  ← ≡⊟ BaseFlatC DblStopG
BlockedG ← ∧(. UpdatePos) StopRwG 0
ModPosG  ← × PosB ¬ BlockedG
PfRG     ← ↘ ¯1 ModPosG
DpG      ← × PfRG × LegAlloc - WtiR NgR
EqG      ← + StartingCapital \+ DpG
DRetG    ← ÷ ↘ ¯1 EqG - ↘ ¯1 EqG ↘ 1 EqG
ShG      ← Rnd × √252 ÷ Std DRetG Mean DRetG
DdG      ← Rnd × 100 /↥ ÷ \↥ EqG - EqG \↥ EqG
TrG      ← Rnd × 100 ÷ StartingCapital - StartingCapital ⊣ EqG
EqPG     ← ↘ IdxPost EqG
DRPG     ← ÷ ↘ ¯1 EqPG - ↘ ¯1 EqPG ↘ 1 EqPG
ShPG     ← Rnd × √252 ÷ Std DRPG Mean DRPG
DdPG     ← Rnd × 100 /↥ ÷ \↥ EqPG - EqPG \↥ EqPG
TdG      ← /+ × = 0 ↘ ¯1 ModPosG ≠ 0 ↘ 1 ModPosG
&p ⊂ "G: NG>3.50 + trail+ratio 3σ    " ⊂ json ShG ⊂ "  " ⊂ json DdG ⊂ "  " ⊂ json TrG ⊂ "    " ⊂ json ShPG ⊂ "  " ⊂ json DdPG ⊂ "  " json TdG

&p ""
&p "Sh = Sharpe ratio, MaxDD = max drawdown %, TotRet = total return %"
&p "Post-2010 = metrics computed from Jan 2010 onward (post-structural-shift)"
