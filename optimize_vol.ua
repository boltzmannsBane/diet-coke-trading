# Experimental!
# optimize_vol.ua — Volatility scaling + trade frequency variants
# Tests different signal filters with vol-scaled position sizing
# 
# Vol scaling: size positions by TargetVol / RealizedVol (20-day, 10% target, 3x cap)
# Reference (no vol scaling): Momentum 5d = 12 trades, Sharpe 0.42, MaxDD 46%

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

# Vol scaling parameters
VolWin    ← 20
TargetVol ← 0.10
MaxScale  ← 3

# ============================================
# HEADER
# ============================================
&p ""
&p "╔══════════════════════════════════════════════════════════════════════════════════════╗"
&p "║                   VOL-SCALED STRATEGY OPTIMIZATION RESULTS                         ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                  | Sharpe | MaxDD% | AnnRet | TotRet  | WinR%  | #Tr | PF  ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MOMENTUM 5-DAY + VOL SCALING ═══════════════
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
# 5-day momentum
RatioChg ← - ↘ ¯5 TrR ↘ 5 TrR
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Mom 5d + vol           | "
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

# ═══════════════ MOMENTUM 3-DAY + VOL SCALING ═══════════════
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
# 3-day momentum
RatioChg ← - ↘ ¯3 TrR ↘ 3 TrR
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Mom 3d + vol           | "
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

# ═══════════════ MOMENTUM 2-DAY + VOL SCALING ═══════════════
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
# 2-day momentum
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Mom 2d + vol           | "
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

# ═══════════════ REGIME FILTER ONLY + VOL SCALING ═══════════════
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
# Regime filter: only trade when vol below median
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
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Regime filter + vol    | "
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

# ═══════════════ MOMENTUM 3-DAY + REGIME FILTER + VOL SCALING ═══════════════
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
# Regime filter mask (pre-momentum trim)
MedianVol ← ⊡ ⌊ ÷ 2 ⧻ RSt ⍆ RSt
InRegime  ← < MedianVol RSt
# 3-day momentum
RatioChg ← - ↘ ¯3 TrR ↘ 3 TrR
TrimLen  ← ⧻ RatioChg
MomDrop  ← - TrimLen ⧻ TrR
TrRm     ← ↘ MomDrop TrR
UBm      ← ↘ MomDrop UB
LBm      ← ↘ MomDrop LBand
RMnm     ← ↘ MomDrop RMn
RStm     ← ↘ MomDrop RSt
TrNgm    ← ↘ MomDrop TrNg
TrWtim   ← ↘ MomDrop TrWti
InRegM   ← ↘ MomDrop InRegime
# Combined: threshold + momentum reversal + regime
RL   ← × InRegM × < 0 RatioChg > UBm TrRm
RS   ← × InRegM × > 0 RatioChg < LBm TrRm
RE   ← - RS RL
NM   ← < × ExitMult RStm ⌵ - RMnm TrRm
SR   ← ≡⊟ NM RE
Pos  ← ∧(. UpdatePos) SR 0
NgR  ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR  ← ↘ ¯1 Pos
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 Pos
CuP     ← ↘ 1 Pos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ Mom 3d + regime + vol  | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Target vol sweep (Mom 2d, varying target vol):                                     ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ MOM 2D + VOL 15% TARGET ═══════════════
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
SprdRet  ← - WtiR NgR
RVol     ← × √252 ⧈(Std) VolWin SprdRet
VolOff   ← - 1 VolWin
VScale   ← ↧ MaxScale ÷ RVol 0.15
SRetV    ← ↘ VolOff SprdRet
PfRv     ← ↘ VolOff PfR
DPnl     ← × PfRv × VScale × LegAlloc SRetV
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
InPos    ← ≠ 0 PfRv
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP      ← ↘ ¯1 Pos
CuP      ← ↘ 1 Pos
NT       ← /+ × = 0 PrP ≠ 0 CuP
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Mom 2d + vol 15%       | "
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

# ═══════════════ MOM 2D + VOL 25% TARGET ═══════════════
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
SprdRet  ← - WtiR NgR
RVol     ← × √252 ⧈(Std) VolWin SprdRet
VolOff   ← - 1 VolWin
VScale   ← ↧ MaxScale ÷ RVol 0.25
SRetV    ← ↘ VolOff SprdRet
PfRv     ← ↘ VolOff PfR
DPnl     ← × PfRv × VScale × LegAlloc SRetV
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
InPos    ← ≠ 0 PfRv
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP      ← ↘ ¯1 Pos
CuP      ← ↘ 1 Pos
NT       ← /+ × = 0 PrP ≠ 0 CuP
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Mom 2d + vol 25%       | "
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

# ═══════════════ MOM 2D + VOL 40% TARGET ═══════════════
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
SprdRet  ← - WtiR NgR
RVol     ← × √252 ⧈(Std) VolWin SprdRet
VolOff   ← - 1 VolWin
VScale   ← ↧ MaxScale ÷ RVol 0.40
SRetV    ← ↘ VolOff SprdRet
PfRv     ← ↘ VolOff PfR
DPnl     ← × PfRv × VScale × LegAlloc SRetV
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
InPos    ← ≠ 0 PfRv
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP      ← ↘ ¯1 Pos
CuP      ← ↘ 1 Pos
NT       ← /+ × = 0 PrP ≠ 0 CuP
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Mom 2d + vol 40%       | "
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

# ═══════════════ MOM 2D, NO VOL (for direct comparison) ═══════════════
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
Pos      ← ∧(. UpdatePos) SR 0
NgR      ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR     ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR      ← ↘ ¯1 Pos
DPnl     ← × PfR × LegAlloc - WtiR NgR
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
InPos    ← ≠ 0 ↘ ¯1 Pos
APnl     ← ▽ InPos DPnl
WR       ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP      ← ↘ ¯1 Pos
CuP      ← ↘ 1 Pos
NT       ← /+ × = 0 PrP ≠ 0 CuP
GP       ← /+ ▽ > 0 APnl APnl
GL       ← /+ ▽ < 0 APnl APnl
PF       ← ÷ ⌵ GL GP

&pf "║ Mom 2d, NO vol         | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant G (NG>3.50 + double stop) with and without vol scaling:                   ║"
&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"

# ═══════════════ VARIANT G (NG>$3.50 + DOUBLE STOP), NO VOL ═══════════════
# Fill-forward: carry last non-zero value
FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)
# Min with reset: on entry day reset to element, else take min
MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)

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
# NG > $3.50 filter on long entries
RL  ← × > 3.5 TrNgm × < 0 RatioChg > UBm TrRm
RS  ← × > 0 RatioChg < LBm TrRm
RE  ← - RS RL
NM  ← < × ExitMult RStm ⌵ - RMnm TrRm
SR  ← ≡⊟ NM RE
Pos ← ∧(. UpdatePos) SR 0
# Double stop-loss
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - RMnm TrRm
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 RStm TrailDist
EntryVal    ← × EntryDay TrRm
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios TrRm
RatioStop   ← × ≠ 0 Pos > × 3.0 RStm RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR        ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
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
InPos       ← ≠ 0 PfR
APnl        ← ▽ InPos DPnl
WR          ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
GP          ← /+ ▽ > 0 APnl APnl
GL          ← /+ ▽ < 0 APnl APnl
PF          ← ÷ ⌵ GL GP

&pf "║ VarG NO vol             | "
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

# ═══════════════ VARIANT G + VOL SCALING 10% ═══════════════
RMn         ← ⧈(Mean) Lb Ratio
RSt         ← ⧈(Std) Lb Ratio
Off         ← - 1 Lb
TrR         ← ↘ Off Ratio
TrNg        ← ↘ Off AlignedNg
TrWti       ← ↘ Off AlignedWti
UB          ← + RMn × Thr RSt
LBand       ← - RMn × Thr RSt
RatioChg    ← - ↘ ¯2 TrR ↘ 2 TrR
TrimLen     ← ⧻ RatioChg
MomDrop     ← - TrimLen ⧻ TrR
TrRm        ← ↘ MomDrop TrR
UBm         ← ↘ MomDrop UB
LBm         ← ↘ MomDrop LBand
RMnm        ← ↘ MomDrop RMn
RStm        ← ↘ MomDrop RSt
TrNgm       ← ↘ MomDrop TrNg
TrWtim      ← ↘ MomDrop TrWti
RL          ← × > 3.5 TrNgm × < 0 RatioChg > UBm TrRm
RS          ← × > 0 RatioChg < LBm TrRm
RE          ← - RS RL
NM          ← < × ExitMult RStm ⌵ - RMnm TrRm
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - RMnm TrRm
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 RStm TrailDist
EntryVal    ← × EntryDay TrRm
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios TrRm
RatioStop   ← × ≠ 0 Pos > × 3.0 RStm RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR        ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR         ← ↘ ¯1 ModPos
# Vol scaling
SprdRet ← - WtiR NgR
RVol    ← × √252 ⧈(Std) VolWin SprdRet
VolOff  ← - 1 VolWin
VScale  ← ↧ MaxScale ÷ RVol TargetVol
SRetV   ← ↘ VolOff SprdRet
PfRv    ← ↘ VolOff PfR
DPnl    ← × PfRv × VScale × LegAlloc SRetV
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
InPos   ← ≠ 0 PfRv
APnl    ← ▽ InPos DPnl
WR      ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP     ← ↘ ¯1 ModPos
CuP     ← ↘ 1 ModPos
NT      ← /+ × = 0 PrP ≠ 0 CuP
GP      ← /+ ▽ > 0 APnl APnl
GL      ← /+ ▽ < 0 APnl APnl
PF      ← ÷ ⌵ GL GP

&pf "║ VarG + vol 10%          | "
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

# ═══════════════ VARIANT G + VOL SCALING 25% ═══════════════
RMn         ← ⧈(Mean) Lb Ratio
RSt         ← ⧈(Std) Lb Ratio
Off         ← - 1 Lb
TrR         ← ↘ Off Ratio
TrNg        ← ↘ Off AlignedNg
TrWti       ← ↘ Off AlignedWti
UB          ← + RMn × Thr RSt
LBand       ← - RMn × Thr RSt
RatioChg    ← - ↘ ¯2 TrR ↘ 2 TrR
TrimLen     ← ⧻ RatioChg
MomDrop     ← - TrimLen ⧻ TrR
TrRm        ← ↘ MomDrop TrR
UBm         ← ↘ MomDrop UB
LBm         ← ↘ MomDrop LBand
RMnm        ← ↘ MomDrop RMn
RStm        ← ↘ MomDrop RSt
TrNgm       ← ↘ MomDrop TrNg
TrWtim      ← ↘ MomDrop TrWti
RL          ← × > 3.5 TrNgm × < 0 RatioChg > UBm TrRm
RS          ← × > 0 RatioChg < LBm TrRm
RE          ← - RS RL
NM          ← < × ExitMult RStm ⌵ - RMnm TrRm
SR          ← ≡⊟ NM RE
Pos         ← ∧(. UpdatePos) SR 0
BaseFlat    ← = 0 Pos
PrPe        ← ⊂ 0 ↘ ¯1 Pos
EntryDay    ← × = 0 PrPe ≠ 0 Pos
DistFromMn  ← ⌵ - RMnm TrRm
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 Pos > × 1.0 RStm TrailDist
EntryVal    ← × EntryDay TrRm
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios TrRm
RatioStop   ← × ≠ 0 Pos > × 3.0 RStm RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPos      ← × Pos ¬ Blocked
NgR         ← ÷ ↘ ¯1 TrNgm - ↘ ¯1 TrNgm ↘ 1 TrNgm
WtiR        ← ÷ ↘ ¯1 TrWtim - ↘ ¯1 TrWtim ↘ 1 TrWtim
PfR         ← ↘ ¯1 ModPos
SprdRet     ← - WtiR NgR
RVol        ← × √252 ⧈(Std) VolWin SprdRet
VolOff      ← - 1 VolWin
VScale      ← ↧ MaxScale ÷ RVol 0.25
SRetV       ← ↘ VolOff SprdRet
PfRv        ← ↘ VolOff PfR
DPnl        ← × PfRv × VScale × LegAlloc SRetV
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
InPos       ← ≠ 0 PfRv
APnl        ← ▽ InPos DPnl
WR          ← × 100 ÷ ⧻ APnl /+ > 0 APnl
PrP         ← ↘ ¯1 ModPos
CuP         ← ↘ 1 ModPos
NT          ← /+ × = 0 PrP ≠ 0 CuP
GP          ← /+ ▽ > 0 APnl APnl
GL          ← /+ ▽ < 0 APnl APnl
PF          ← ÷ ⌵ GL GP

&pf "║ VarG + vol 25%          | "
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

&p "╠══════════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Reference (no vol scaling):                                                        ║"
&p "║   Baseline (no filter):  Sharpe 0.32, MaxDD 63%, 79 trades                        ║"
&p "║   Momentum 5d:           Sharpe 0.42, MaxDD 46%, 12 trades                        ║"
&p "║   Regime filter:         Sharpe 0.38, MaxDD 63%, 58 trades                        ║"
&p "║   Variant G (main.ua):   Sharpe 0.49, MaxDD 35.6%, 18 trades                     ║"
&p "╚══════════════════════════════════════════════════════════════════════════════════════╝"
