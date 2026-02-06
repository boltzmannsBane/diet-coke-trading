# test_startdate.ua — Test strategy Sharpe for different starting years
# Does the post-2009 structural NG/WTI decoupling improve performance?

# ============================================
# Data loading & strategy (same as main.ua)
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

RawLong  ← × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
RawEntry ← - RawShort RawLong
NearMean ← < × 0.5 MRSt ⌵ - MRMn MR

UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

SignalRows ← ≡⊟ NearMean RawEntry
Positions  ← ∧(. UpdatePos) SignalRows 0

NgRet     ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiRet    ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PosForRet ← ↘ ¯1 Positions
DailyPnl  ← × PosForRet × LegAlloc - WtiRet NgRet
Equity    ← + StartingCapital \+ DailyPnl
EqDates   ← ↘ 1 MDates

# ============================================
# Sharpe by start year
# ============================================
&p "══════════════════════════════════════════════════════════════════════════════"
&p "SHARPE BY START YEAR — Does post-2009 structural shift improve performance?"
&p "══════════════════════════════════════════════════════════════════════════════"
&p ""
&p "Start     Sharpe  MaxDD%  AnnRet%  TotRet%  Trades  Years"
&p "────────  ──────  ──────  ───────  ───────  ──────  ─────"

ExtractYear ← ⋕ ↙4 °□
YearsArr    ← ≡ExtractYear EqDates

# --- Full period (A) ---
NnA  ← ⧻ DailyPnl
YrsA ← ÷ 252 NnA
DRA  ← ÷ ↘ ¯1 Equity - ↘ ¯1 Equity ↘ 1 Equity
ShA  ← × √252 ÷ Std DRA Mean DRA
PkA  ← \↥ Equity
DdA  ← × 100 /↥ ÷ PkA - Equity PkA
TrA  ← × 100 ÷ StartingCapital - StartingCapital ⊣ Equity
ArA  ← × 100 - 1 ⁿ ÷ YrsA 1 ÷ StartingCapital ⊣ Equity
PvA  ← ↘ ¯1 Positions
CvA  ← ↘ 1 Positions
TdA  ← /+ × = 0 PvA ≠ 0 CvA
&p ⊂ "1997      " ⊂ json Rnd ShA ⊂ "    " ⊂ json Rnd DdA ⊂ "    " ⊂ json Rnd ArA ⊂ "      " ⊂ json Rnd TrA ⊂ "     " ⊂ json TdA ⊂ "      " json Rnd YrsA

# --- From 2003 (B) ---
IdxB ← /+ < 2003 YearsArr
EqB  ← ↘ IdxB Equity
EqSB ← ⊡ 0 EqB
NnB  ← - 1 ⧻ EqB
YrsB ← ÷ 252 NnB
DRB  ← ÷ ↘ ¯1 EqB - ↘ ¯1 EqB ↘ 1 EqB
ShB  ← × √252 ÷ Std DRB Mean DRB
PkB  ← \↥ EqB
DdB  ← × 100 /↥ ÷ PkB - EqB PkB
TrB  ← × 100 ÷ EqSB - EqSB ⊣ EqB
ArB  ← × 100 - 1 ⁿ ÷ YrsB 1 ÷ EqSB ⊣ EqB
PfB  ← ↘ IdxB PosForRet
PvB  ← ↘ ¯1 PfB
CvB  ← ↘ 1 PfB
TdB  ← /+ × = 0 PvB ≠ 0 CvB
&p ⊂ "2003      " ⊂ json Rnd ShB ⊂ "    " ⊂ json Rnd DdB ⊂ "    " ⊂ json Rnd ArB ⊂ "      " ⊂ json Rnd TrB ⊂ "     " ⊂ json TdB ⊂ "      " json Rnd YrsB

# --- From 2010 (C) --- THE KEY TEST ---
IdxC ← /+ < 2010 YearsArr
EqC  ← ↘ IdxC Equity
EqSC ← ⊡ 0 EqC
NnC  ← - 1 ⧻ EqC
YrsC ← ÷ 252 NnC
DRC  ← ÷ ↘ ¯1 EqC - ↘ ¯1 EqC ↘ 1 EqC
ShC  ← × √252 ÷ Std DRC Mean DRC
PkC  ← \↥ EqC
DdC  ← × 100 /↥ ÷ PkC - EqC PkC
TrC  ← × 100 ÷ EqSC - EqSC ⊣ EqC
ArC  ← × 100 - 1 ⁿ ÷ YrsC 1 ÷ EqSC ⊣ EqC
PfC  ← ↘ IdxC PosForRet
PvC  ← ↘ ¯1 PfC
CvC  ← ↘ 1 PfC
TdC  ← /+ × = 0 PvC ≠ 0 CvC
&p ⊂ "2010 ★    " ⊂ json Rnd ShC ⊂ "    " ⊂ json Rnd DdC ⊂ "    " ⊂ json Rnd ArC ⊂ "      " ⊂ json Rnd TrC ⊂ "     " ⊂ json TdC ⊂ "      " json Rnd YrsC

# --- From 2015 (D) ---
IdxD ← /+ < 2015 YearsArr
EqD  ← ↘ IdxD Equity
EqSD ← ⊡ 0 EqD
NnD  ← - 1 ⧻ EqD
YrsD ← ÷ 252 NnD
DRD  ← ÷ ↘ ¯1 EqD - ↘ ¯1 EqD ↘ 1 EqD
ShD  ← × √252 ÷ Std DRD Mean DRD
PkD  ← \↥ EqD
DdD  ← × 100 /↥ ÷ PkD - EqD PkD
TrD  ← × 100 ÷ EqSD - EqSD ⊣ EqD
ArD  ← × 100 - 1 ⁿ ÷ YrsD 1 ÷ EqSD ⊣ EqD
PfD  ← ↘ IdxD PosForRet
PvD  ← ↘ ¯1 PfD
CvD  ← ↘ 1 PfD
TdD  ← /+ × = 0 PvD ≠ 0 CvD
&p ⊂ "2015      " ⊂ json Rnd ShD ⊂ "    " ⊂ json Rnd DdD ⊂ "    " ⊂ json Rnd ArD ⊂ "      " ⊂ json Rnd TrD ⊂ "     " ⊂ json TdD ⊂ "      " json Rnd YrsD

# --- From 2020 (E) ---
IdxE ← /+ < 2020 YearsArr
EqE  ← ↘ IdxE Equity
EqSE ← ⊡ 0 EqE
NnE  ← - 1 ⧻ EqE
YrsE ← ÷ 252 NnE
DRE  ← ÷ ↘ ¯1 EqE - ↘ ¯1 EqE ↘ 1 EqE
ShE  ← × √252 ÷ Std DRE Mean DRE
PkE  ← \↥ EqE
DdE  ← × 100 /↥ ÷ PkE - EqE PkE
TrE  ← × 100 ÷ EqSE - EqSE ⊣ EqE
ArE  ← × 100 - 1 ⁿ ÷ YrsE 1 ÷ EqSE ⊣ EqE
PfE  ← ↘ IdxE PosForRet
PvE  ← ↘ ¯1 PfE
CvE  ← ↘ 1 PfE
TdE  ← /+ × = 0 PvE ≠ 0 CvE
&p ⊂ "2020      " ⊂ json Rnd ShE ⊂ "    " ⊂ json Rnd DdE ⊂ "    " ⊂ json Rnd ArE ⊂ "      " ⊂ json Rnd TrE ⊂ "     " ⊂ json TdE ⊂ "      " json Rnd YrsE

&p ""
&p "★ = post-structural-shift (shale gas revolution decoupled NG/WTI in 2009)"
&p ""
&p "Note: Rolling stats (60d mean/std) computed on full history from 1997."
&p "Start year only affects the period over which metrics are measured."
&p "Equity at start of each period carries forward from earlier trading."
