# Experimental!
# optimize_adaptive.ua — Adaptive exit strategy sweep
# Tests: fixed exit thresholds (0.5σ to 1.5σ) + proportional recovery exits

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

# ============================================
# SHARED: Rolling stats + 2-day momentum + entry signals
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

RatioChg ← - ↘ ¯2 TrimmedRatio ↘ 2 TrimmedRatio
MomDrop  ← - ⧻ RatioChg ⧻ TrimmedRatio
MR       ← ↘ MomDrop TrimmedRatio
MNg      ← ↘ MomDrop TrimmedNg
MWti     ← ↘ MomDrop TrimmedWti
MUB      ← ↘ MomDrop UpperBand
MLB      ← ↘ MomDrop LowerBand
MRMn     ← ↘ MomDrop RMean
MRSt     ← ↘ MomDrop RStd

# Entry signals (same for ALL variants — only exit changes)
RawLong  ← × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
RawEntry ← - RawShort RawLong

# Returns (shared)
NgR  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiR ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti

&p ""
&p "╔═════════════════════════════════════════════════════════════════════════════════╗"
&p "║                      ADAPTIVE EXIT STRATEGY SWEEP                            ║"
&p "╠═════════════════════════════════════════════════════════════════════════════════╣"
&p "║ Variant                  | Sharpe | MaxDD% | AnnRet% | TotRet% | #Tr | PF    ║"
&p "╠═════════════════════════════════════════════════════════════════════════════════╣"

# ════════════════════════════════════════════════════════════════
# FIXED EXIT THRESHOLDS
# Exit when |ratio - mean| < X × σ (larger X = exit earlier)
# ════════════════════════════════════════════════════════════════

# --- Exit 0.5σ (current baseline) ---
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
NT         ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
ShA        ← Sh
DdA        ← MaxDd
&pf "║ Exit 0.5σ (baseline)     | "
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

# --- Exit 0.75σ ---
NearMean   ← < × 0.75 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
NT         ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
ShB        ← Sh
DdB        ← MaxDd
&pf "║ Exit 0.75σ               | "
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

# --- Exit 1.0σ ---
NearMean   ← < × 1.0 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
NT         ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
ShC        ← Sh
DdC        ← MaxDd
&pf "║ Exit 1.0σ                | "
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

# --- Exit 1.25σ ---
NearMean   ← < × 1.25 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
NT         ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
ShD        ← Sh
DdD        ← MaxDd
&pf "║ Exit 1.25σ               | "
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

# --- Exit 1.5σ ---
NearMean   ← < × 1.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0
PfR        ← ↘ ¯1 Pos
DPnl       ← × PfR × LegAlloc - WtiR NgR
Eqt        ← + StartingCapital \+ DPnl
TotRet     ← × 100 ÷ StartingCapital - StartingCapital ⊣ Eqt
AnnRet     ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ DPnl 1 ÷ StartingCapital ⊣ Eqt
Pk         ← \↥ Eqt
MaxDd      ← × 100 /↥ ÷ Pk - Eqt Pk
DRet       ← ÷ ↘ ¯1 Eqt - ↘ ¯1 Eqt ↘ 1 Eqt
Sh         ← × √252 ÷ Std DRet Mean DRet
NT         ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InPos      ← ≠ 0 ↘ ¯1 Pos
APnl       ← ▽ InPos DPnl
GP         ← /+ ▽ > 0 APnl APnl
GL         ← /+ ▽ < 0 APnl APnl
PF         ← ÷ ⌵ GL GP
ShE        ← Sh
DdE        ← MaxDd
&pf "║ Exit 1.5σ                | "
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

# ════════════════════════════════════════════════════════════════
# PROPORTIONAL RECOVERY EXIT
# Exit when X% of entry distance from mean has been recovered
# Post-processed on top of standard 0.5σ exit positions
# ════════════════════════════════════════════════════════════════

# Recompute base positions with standard exit
NearMean   ← < × 0.5 MRSt ⌵ - MRMn MR
SignalRows ← ≡⊟ NearMean RawEntry
Pos        ← ∧(. UpdatePos) SignalRows 0

# Entry detection
BaseFlat ← = 0 Pos
PrPe     ← ⊂ 0 ↘ ¯1 Pos
EntryDay ← × = 0 PrPe ≠ 0 Pos

# Entry distance from mean (fill-forward from entry days)
EntryDistFromMean   ← ↥ 0.001 FillFwd × EntryDay ⌵ - MRMn MR
CurrentDistFromMean ← ⌵ - MRMn MR

# Recovery fraction: 0 at entry, 1 at full mean reversion
RecoveryFrac ← - ÷ EntryDistFromMean CurrentDistFromMean 1

# --- Proportional 25% (aggressive profit-taking) ---
StopMask ← × ≠ 0 Pos > 0.25 RecoveryFrac
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
&pf "║ Prop exit 25% recovery   | "
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

# --- Proportional 50% ---
StopMask ← × ≠ 0 Pos > 0.50 RecoveryFrac
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
&pf "║ Prop exit 50% recovery   | "
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

# --- Proportional 75% ---
StopMask ← × ≠ 0 Pos > 0.75 RecoveryFrac
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
&pf "║ Prop exit 75% recovery   | "
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

# ════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════
AllSh ← [ShA ShB ShC ShD ShE ShF ShG ShH]
AllDd ← [DdA DdB DdC DdD DdE DdF DdG DdH]
Names ← {"0.5σ" "0.75σ" "1.0σ" "1.25σ" "1.5σ" "prop25%" "prop50%" "prop75%"}

BestShIdx ← ˜⨂ /↥ . AllSh
BestDdIdx ← ˜⨂ /↧ . AllDd

&p ""
&p ⊂ "Best Sharpe:  " ⊂ json Rnd ⊡ BestShIdx AllSh ⊂ " — " °□ ⊡ BestShIdx Names
&p ⊂ "Lowest MaxDD: " ⊂ json Rnd ⊡ BestDdIdx AllDd ⊂ "% — " °□ ⊡ BestDdIdx Names
