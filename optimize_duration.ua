# Experimental!
# optimize_duration.ua — Trade duration limits + transaction costs
# Tests max hold periods (5d, 21d, 63d) with and without trading costs
# Base signal: 2-day momentum filter (60/2.0/0.5)
# 
# Transaction costs: 10 bps (0.1%) per side per leg on each position change
# Per trade event (entry or exit): 2 legs × 0.1% × $50k = $100

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

# Cost per position change: 2 legs × 10 bps × $50k = $100
CostPerEvent ← × 2 × 0.001 LegAlloc

# ============================================
# SHARED SIGNAL GENERATION (2-day momentum, 60/2.0/0.5)
# ============================================
Lb       ← 60
Thr      ← 2.0
ExitMult ← 0.5

RMn      ← ⧈(Mean) Lb Ratio
RSt      ← ⧈(Std) Lb Ratio
Off      ← - 1 Lb
TrR      ← ↘ Off Ratio
TrNg     ← ↘ Off AlignedNg
TrWti    ← ↘ Off AlignedWti
UB       ← + RMn × Thr RSt
LBand    ← - RMn × Thr RSt
RatioChg ← - ↘ ¯2 TrR ↘ 2 TrR
TrimLen  ← ⧻ RatioChg
MomDrop  ← - TrimLen ⧻ TrR
TrRm     ← ↘ MomDrop TrR
UBm      ← ↘ MomDrop UB
LBm      ← ↘ MomDrop LBand
RMnm     ← ↘ MomDrop RMn
RStm     ← ↘ MomDrop RSt
TrNgm    ← ↘ MomDrop TrNg
TrWtim   ← ↘ MomDrop TrWti
RL       ← × < 0 RatioChg > UBm TrRm
RS       ← × > 0 RatioChg < LBm TrRm
RE       ← - RS RL
NM       ← < × ExitMult RStm ⌵ - RMnm TrRm
SR       ← ≡⊟ NM RE
# Base positions (no duration limit)
BasePos ← ∧(. UpdatePos) SR 0
# Base daily returns (shared across all variants)
NgR  ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
# Consecutive days in position (for duration limiting)
BaseDaysIn ← ∧(. ×⊃(+1 ⋅∘|≠ 0 ∘)) BasePos 0

# ============================================
# HEADER
# ============================================
&p ""
&p "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
&p "║                   DURATION & TRANSACTION COST OPTIMIZATION                              ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                      | Sharpe | MaxDD% | AnnRet | TotRet  | WinR%  | #Tr | PF  ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ NO LIMIT, NO COSTS (reference) ═══════════════
Pos     ← BasePos
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

&pf "║ No limit, no costs          | "
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

# ═══════════════ NO LIMIT, WITH COSTS ═══════════════
Pos ← BasePos
PfR ← ↘ ¯1 Pos
# Detect position changes for cost calculation
PfRlag   ← ⊂ 0 ↘ ¯1 PfR
TradeDay ← ≠ PfRlag PfR
Costs    ← × TradeDay CostPerEvent
DPnl     ← - Costs × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
FinalEq  ← ⊣ Eqt
Nn       ← ⧻ DPnl
Yrs      ← ÷ 252 Nn
TotRet   ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
InPos    ← ≠ 0 PfR
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP      ← ↘ ¯1 Pos
CuP      ← ↘ 1 Pos
NT       ← /+ × = 0 PrP ≠ 0 CuP
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ No limit, 10bps costs       | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MAX 5 DAYS (1 week), NO COSTS ═══════════════
PosClip ← × BasePos ≤ 5 BaseDaysIn
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
InPos   ← ≠ 0 PfR
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PfRlag  ← ⊂ 0 ↘ ¯1 PfR
NT      ← /+ × = 0 PfRlag ≠ 0 PfR
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Max 5d (week), no costs     | "
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

# ═══════════════ MAX 5 DAYS (1 week), WITH COSTS ═══════════════
PosClip  ← × BasePos ≤ 5 BaseDaysIn
PfR      ← ↘ ¯1 PosClip
PfRlag   ← ⊂ 0 ↘ ¯1 PfR
TradeDay ← ≠ PfRlag PfR
Costs    ← × TradeDay CostPerEvent
DPnl     ← - Costs × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
FinalEq  ← ⊣ Eqt
Nn       ← ⧻ DPnl
Yrs      ← ÷ 252 Nn
TotRet   ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
InPos    ← ≠ 0 PfR
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
NT       ← /+ × = 0 PfRlag ≠ 0 PfR
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Max 5d (week), 10bps costs  | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MAX 21 DAYS (1 month), NO COSTS ═══════════════
PosClip ← × BasePos ≤ 21 BaseDaysIn
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
InPos   ← ≠ 0 PfR
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PfRlag  ← ⊂ 0 ↘ ¯1 PfR
NT      ← /+ × = 0 PfRlag ≠ 0 PfR
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Max 21d (month), no costs   | "
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

# ═══════════════ MAX 21 DAYS (1 month), WITH COSTS ═══════════════
PosClip  ← × BasePos ≤ 21 BaseDaysIn
PfR      ← ↘ ¯1 PosClip
PfRlag   ← ⊂ 0 ↘ ¯1 PfR
TradeDay ← ≠ PfRlag PfR
Costs    ← × TradeDay CostPerEvent
DPnl     ← - Costs × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
FinalEq  ← ⊣ Eqt
Nn       ← ⧻ DPnl
Yrs      ← ÷ 252 Nn
TotRet   ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
InPos    ← ≠ 0 PfR
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
NT       ← /+ × = 0 PfRlag ≠ 0 PfR
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Max 21d (month), 10bps      | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MAX 63 DAYS (3 months), NO COSTS ═══════════════
PosClip ← × BasePos ≤ 63 BaseDaysIn
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
InPos   ← ≠ 0 PfR
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PfRlag  ← ⊂ 0 ↘ ¯1 PfR
NT      ← /+ × = 0 PfRlag ≠ 0 PfR
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Max 63d (3 mo), no costs    | "
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

# ═══════════════ MAX 63 DAYS (3 months), WITH COSTS ═══════════════
PosClip  ← × BasePos ≤ 63 BaseDaysIn
PfR      ← ↘ ¯1 PosClip
PfRlag   ← ⊂ 0 ↘ ¯1 PfR
TradeDay ← ≠ PfRlag PfR
Costs    ← × TradeDay CostPerEvent
DPnl     ← - Costs × PfR × LegAlloc - WtiR NgR
Eqt      ← + StartingCapital \+ DPnl
FinalEq  ← ⊣ Eqt
Nn       ← ⧻ DPnl
Yrs      ← ÷ 252 Nn
TotRet   ← × 100 ÷ StartingCapital - StartingCapital FinalEq
AnnRet   ← × 100 - 1 ⁿ ÷ Yrs 1 ÷ StartingCapital FinalEq
Pk       ← \↥ Eqt
MaxDd    ← × 100 /↥ ÷ Pk - Eqt Pk
DRet     ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh       ← × √252 ÷ Std DRet Mean DRet
InPos    ← ≠ 0 PfR
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
NT       ← /+ × = 0 PfRlag ≠ 0 PfR
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Max 63d (3 mo), 10bps       | "
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

&p "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
