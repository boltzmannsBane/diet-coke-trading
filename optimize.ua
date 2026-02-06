# Experimental!
# optimize.ua — Strategy optimization & parameter sweep
# Tests all improvement ideas from NOTES.md
# All computation at top level (functions + global arrays unreliable in UIUA 0.17.2)

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
# HELPERS (simple functions, no global array refs)
# ============================================
Mean            ← ÷⊃⧻(/+)
Std             ← √ Mean ⁿ2 - Mean .
Rnd             ← ÷ 100 ⁅ × 100
StartingCapital ← 100000
LegAlloc        ← ÷ 2 StartingCapital

# Position update: [entry exit] prev -> new_pos
UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

# ============================================
# HEADER
# ============================================
&p ""
&p "╔══════════════════════════════════════════════════════════════════════════════════╗"
&p "║                        STRATEGY OPTIMIZATION RESULTS                           ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant              | Sharpe | MaxDD% | AnnRet | TotRet  | WinR%  | #Tr | PF  ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════╣"

# ============================================
# MACRO: Strategy + Backtest + Metrics (inline at top level)
# Input: Lb Thr ExitMult (already set as top-level bindings)
# Output: MetricsArr = [Sh MaxDd AnnRet TotRet WR NT PF]
# ============================================

# ═══════════════ BASELINE (60/2.0/0.5) ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Baseline 60/2.0/0.5  | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ LOOKBACK = 30 ═══════════════
Lb       ← 30
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Lookback=30          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ LOOKBACK = 45 ═══════════════
Lb       ← 45
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Lookback=45          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ LOOKBACK = 90 ═══════════════
Lb       ← 90
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Lookback=90          | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ LOOKBACK = 120 ═══════════════
Lb       ← 120
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Lookback=120         | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ THRESHOLD = 1.5 ═══════════════
Lb       ← 60
Thr      ← 1.5
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Threshold=1.5        | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ THRESHOLD = 2.5 ═══════════════
Lb       ← 60
Thr      ← 2.5
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Threshold=2.5        | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ EXIT = 0.25σ ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.25

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Exit=0.25σ           | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ EXIT = 0.0σ (at mean) ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.0

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Exit=0.0σ (at mean)  | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

&p "╠══════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ SPIKE CAP ±5% ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn     ← ⧈(Mean) Lb Ratio
RSt     ← ⧈(Std) Lb Ratio
Off     ← - 1 Lb
TrR     ← ↘ Off Ratio
TrNg    ← ↘ Off AlignedNg
TrWti   ← ↘ Off AlignedWti
UB      ← + RMn × Thr RSt
LBand   ← - RMn × Thr RSt
RL      ← > UB TrR
RS      ← < LBand TrR
RE      ← - RS RL
NM      ← < × ExitMult RSt ⌵ - RMn TrR
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ + Spike cap ±5%      | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ MAX DURATION 120 DAYS ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrNg  ← ↘ Off AlignedNg
TrWti ← ↘ Off AlignedWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt
RL    ← > UB TrR
RS    ← < LBand TrR
RE    ← - RS RL
NM    ← < × ExitMult RSt ⌵ - RMn TrR
SR    ← ≡⊟ NM RE
Pos   ← ∧(. UpdatePos) SR 0
# Count consecutive days in position
DaysIn ← ∧(. ×⊃(+1 ⋅∘|≠ 0 ∘)) Pos 0
# Force exit after 120 days
PosClip ← × Pos ≤ 120 DaysIn
NgR     ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 PosClip
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
InPos   ← ≠ 0 ↘ ¯1 PosClip
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 PosClip
CuP     ← ↘ 1 PosClip
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ + Max duration 120d  | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ MOMENTUM FILTER ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrNg  ← ↘ Off AlignedNg
TrWti ← ↘ Off AlignedWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt
# 5-day ratio change
RatioChg ← - ↘ ¯5 TrR ↘ 5 TrR
TrimLen  ← ⧻ RatioChg
TrRm     ← ↘ - TrimLen ⧻ TrR TrR
UBm      ← ↘ - TrimLen ⧻ UB UB
LBm      ← ↘ - TrimLen ⧻ LBand LBand
RMnm     ← ↘ - TrimLen ⧻ RMn RMn
RStm     ← ↘ - TrimLen ⧻ RSt RSt
TrNgm    ← ↘ - TrimLen ⧻ TrNg TrNg
TrWtim   ← ↘ - TrimLen ⧻ TrWti TrWti
# Long: ratio > upper AND ratio falling (reversal)
RL      ← × < 0 RatioChg > UBm TrRm
RS      ← × > 0 RatioChg < LBm TrRm
RE      ← - RS RL
NM      ← < × ExitMult RStm ⌵ - RMnm TrRm
SR      ← ≡⊟ NM RE
Pos     ← ∧(. UpdatePos) SR 0
NgR     ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR    ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR     ← ↘ ¯1 Pos
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
InPos   ← ≠ 0 ↘ ¯1 Pos
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ + Momentum filter    | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ REGIME FILTER ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrNg  ← ↘ Off AlignedNg
TrWti ← ↘ Off AlignedWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt
# Only trade when vol below median (mean-reverting regime)
MedianVol ← ⊡ ⌊ ÷ 2 ⧻ RSt ⍆ RSt
InRegime  ← < MedianVol RSt
RL        ← × InRegime > UB TrR
RS        ← × InRegime < LBand TrR
RE        ← - RS RL
NM        ← < × ExitMult RSt ⌵ - RMn TrR
SR        ← ≡⊟ NM RE
Pos       ← ∧(. UpdatePos) SR 0
NgR       ← ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR      ← ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR       ← ↘ ¯1 Pos
DPnl      ← × PfR × LegAlloc - WtiR NgR
Eqt       ← + StartingCapital \+ DPnl
FinalEq   ← ⊣ Eqt
Nn        ← ⧻ DPnl
Yrs       ← ÷ 252 Nn
TotRet    ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet    ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk        ← \↥ Eqt
MaxDd     ← × 100 /↥ ÷ Pk - Eqt Pk
DRet      ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh        ← × √252 ÷ Std DRet Mean DRet
InPos     ← ≠ 0 ↘ ¯1 Pos
APnl      ← ▽ InPos DPnl
WR        ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP       ← ↘ ¯1 Pos
CuP       ← ↘ 1 Pos
NT        ← /+ × = 0 PrP ≠ 0 CuP
GP        ← /+ ▽ > 0 APnl APnl
GL        ← /+ ▽ < 0 APnl APnl
PF        ← ÷ ⌵ GL GP

&pf "║ + Regime filter      | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

&p "╠══════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ COMBINED: Spike cap + Max duration + Regime ═══════════════
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrNg  ← ↘ Off AlignedNg
TrWti ← ↘ Off AlignedWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt
# Regime filter
MedianVol ← ⊡ ⌊ ÷ 2 ⧻ RSt ⍆ RSt
InRegime  ← < MedianVol RSt
RL        ← × InRegime > UB TrR
RS        ← × InRegime < LBand TrR
RE        ← - RS RL
NM        ← < × ExitMult RSt ⌵ - RMn TrR
SR        ← ≡⊟ NM RE
Pos       ← ∧(. UpdatePos) SR 0
# Max duration
DaysIn  ← ∧(. ×⊃(+1 ⋅∘|≠ 0 ∘)) Pos 0
PosClip ← × Pos ≤ 120 DaysIn
# Spike cap
NgR     ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR    ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR     ← ↘ ¯1 PosClip
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
InPos   ← ≠ 0 ↘ ¯1 PosClip
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 PosClip
CuP     ← ↘ 1 PosClip
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ COMBINED cap+dur+reg | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

# ═══════════════ COMBINED: 90/2.5/0.25 + cap + dur + regime ═══════════════
Lb       ← 90
Thr      ← 2.5
ExitMult ← 0.25

RMn       ← ⧈(Mean) Lb Ratio
RSt       ← ⧈(Std) Lb Ratio
Off       ← - 1 Lb
TrR       ← ↘ Off Ratio
TrNg      ← ↘ Off AlignedNg
TrWti     ← ↘ Off AlignedWti
UB        ← + RMn × Thr RSt
LBand     ← - RMn × Thr RSt
MedianVol ← ⊡ ⌊ ÷ 2 ⧻ RSt ⍆ RSt
InRegime  ← < MedianVol RSt
RL        ← × InRegime > UB TrR
RS        ← × InRegime < LBand TrR
RE        ← - RS RL
NM        ← < × ExitMult RSt ⌵ - RMn TrR
SR        ← ≡⊟ NM RE
Pos       ← ∧(. UpdatePos) SR 0
DaysIn    ← ∧(. ×⊃(+1 ⋅∘|≠ 0 ∘)) Pos 0
PosClip   ← × Pos ≤ 120 DaysIn
NgR       ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrNg - ↘ ¯1 TrNg ↘ 1 TrNg
WtiR      ← ↧ 0.05 ↥ ¯0.05 ÷ ↘ ¯1 TrWti - ↘ ¯1 TrWti ↘ 1 TrWti
PfR       ← ↘ ¯1 PosClip
DPnl      ← × PfR × LegAlloc - WtiR NgR
Eqt       ← + StartingCapital \+ DPnl
FinalEq   ← ⊣ Eqt
Nn        ← ⧻ DPnl
Yrs       ← ÷ 252 Nn
TotRet    ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet    ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk        ← \↥ Eqt
MaxDd     ← × 100 /↥ ÷ Pk - Eqt Pk
DRet      ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh        ← × √252 ÷ Std DRet Mean DRet
InPos     ← ≠ 0 ↘ ¯1 PosClip
APnl      ← ▽ InPos DPnl
WR        ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP       ← ↘ ¯1 PosClip
CuP       ← ↘ 1 PosClip
NT        ← /+ × = 0 PrP ≠ 0 CuP
GP        ← /+ ▽ > 0 APnl APnl
GL        ← /+ ▽ < 0 APnl APnl
PF        ← ÷ ⌵ GL GP

&pf "║ COMBINED 90/2.5/best | "
&pf json Rnd Sh
&pf " | "
&pf json Rnd MaxDd
&pf " | "
&pf json Rnd AnnRet
&pf " | "
&pf json Rnd TotRet
&pf " | "
&pf json Rnd WR
&pf " | "
&pf json ⁅ NT
&pf " | "
&p json Rnd PF

&p "╚══════════════════════════════════════════════════════════════════════════════════╝"
