# optimize_seasonal.ua — NG Seasonal drawdown mitigation
# Tests filters and stops to reduce 86% MaxDD

StripCr    ← ▽ ≠@\r .
HasPrice   ← > 1 ⧻ ⊜□ ≠@, . °□
ParseDate  ← °□⊢ ⊜□ ≠@, . °□
ParsePrice ← ⋕°□⊡1 ⊜□ ≠@, . °□
ParseCsv ← (
  ↘1 ⊜□ ≠@\n . StripCr &fras
  ▽ ≡HasPrice .
  ⊃(≡ParseDate|≡ParsePrice)
)
Mean         ← ÷⊃⧻(/+)
Std          ← √ Mean ⁿ2 - Mean .
Rnd          ← ÷ 100 ⁅ × 100
ExtractMonth ← ⋕ ↙2 ↘5 °□

# Position tracking (same as main.ua)
UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

# Running max with reset on flag
MaxResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↥|⊙◌)
)

ParseCsv "data/ng_daily.csv"
NgDates  ←
NgPrices ←

&p "╔══════════════════════════════════════════════════════════════╗"
&p "║         NG SEASONAL DRAWDOWN MITIGATION                    ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ⊂ "NG records: " json ⧻ NgPrices
&p ""

Capital ← 100000

# Common setup
Months   ← ≡ExtractMonth NgDates
IsWinter ← ↥ ≥ 10 Months ≤ 3 Months
NgRet    ← ÷ ↘ ¯1 NgPrices - ↘ ¯1 NgPrices ↘ 1 NgPrices
BasePos  ← ↘ ¯1 IsWinter
NgAlign  ← ↘ 1 NgPrices

# Entry days: first day of each winter
PrevWin  ← ⊂ 0 ↘ ¯1 BasePos
EntryDay ← × BasePos = 0 PrevWin

# ========== VARIANT A: No filter (baseline) ==========
Pnl ← × BasePos NgRet
Eq  ← + Capital \+ × Capital Pnl
ShA ← × √252 ÷ Std Pnl Mean Pnl
DdA ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrA ← × 100 ÷ Capital - Capital ⊣ Eq
ArA ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnA ← /+ EntryDay

# ========== VARIANT B: NG > $3.50 filter ==========
Pos ← × BasePos > 3.5 NgAlign
Pnl ← × Pos NgRet
Eq  ← + Capital \+ × Capital Pnl
ShB ← × √252 ÷ Std Pnl Mean Pnl
DdB ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrB ← × 100 ÷ Capital - Capital ⊣ Eq
ArB ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnB ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== VARIANT C: NG > 50d MA (uptrend filter) ==========
NgMAfifty ← ⧈(Mean) 50 NgPrices
AboveMA   ← > NgMAfifty ↘ 49 NgPrices
TrimC     ← 49
BasePosC  ← ↘ TrimC BasePos
NgRetC    ← ↘ TrimC NgRet
FilterC   ← ↘ ¯1 AboveMA
Pos       ← × BasePosC FilterC
Pnl       ← × Pos NgRetC
Eq        ← + Capital \+ × Capital Pnl
ShC       ← × √252 ÷ Std Pnl Mean Pnl
DdC       ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrC       ← × 100 ÷ Capital - Capital ⊣ Eq
ArC       ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnC       ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== VARIANT D: 25% trailing stop ==========
# Track peak NG price per winter, exit if drops 25%
PeakRows  ← ≡⊟ EntryDay NgAlign
RunPeak   ← ∧(. MaxResetFn) PeakRows 0
StopTrig  ← × BasePos < × 0.75 RunPeak NgAlign
LatchRows ← ≡⊟ EntryDay StopTrig
Blocked   ← ∧(. MaxResetFn) LatchRows 0
Pos       ← × BasePos ¬ Blocked
Pnl       ← × Pos NgRet
Eq        ← + Capital \+ × Capital Pnl
ShD       ← × √252 ÷ Std Pnl Mean Pnl
DdD       ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrD       ← × 100 ÷ Capital - Capital ⊣ Eq
ArD       ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnD       ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== VARIANT E: 15% trailing stop ==========
PeakRows  ← ≡⊟ EntryDay NgAlign
RunPeak   ← ∧(. MaxResetFn) PeakRows 0
StopTrig  ← × BasePos < × 0.85 RunPeak NgAlign
LatchRows ← ≡⊟ EntryDay StopTrig
Blocked   ← ∧(. MaxResetFn) LatchRows 0
Pos       ← × BasePos ¬ Blocked
Pnl       ← × Pos NgRet
Eq        ← + Capital \+ × Capital Pnl
ShE       ← × √252 ÷ Std Pnl Mean Pnl
DdE       ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrE       ← × 100 ÷ Capital - Capital ⊣ Eq
ArE       ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnE       ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== VARIANT F: NG > $3.50 + 25% trailing stop ==========
PeakRows  ← ≡⊟ EntryDay NgAlign
RunPeak   ← ∧(. MaxResetFn) PeakRows 0
NgFilter  ← > 3.5 NgAlign
StopTrig  ← × BasePos < × 0.75 RunPeak NgAlign
LatchRows ← ≡⊟ EntryDay StopTrig
Blocked   ← ∧(. MaxResetFn) LatchRows 0
Pos       ← × × NgFilter BasePos ¬ Blocked
Pnl       ← × Pos NgRet
Eq        ← + Capital \+ × Capital Pnl
ShF       ← × √252 ÷ Std Pnl Mean Pnl
DdF       ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrF       ← × 100 ÷ Capital - Capital ⊣ Eq
ArF       ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnF       ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== VARIANT G: NG > $3.50 + 15% trailing stop ==========
PeakRows  ← ≡⊟ EntryDay NgAlign
RunPeak   ← ∧(. MaxResetFn) PeakRows 0
NgFilter  ← > 3.5 NgAlign
StopTrig  ← × BasePos < × 0.85 RunPeak NgAlign
LatchRows ← ≡⊟ EntryDay StopTrig
Blocked   ← ∧(. MaxResetFn) LatchRows 0
Pos       ← × × NgFilter BasePos ¬ Blocked
Pnl       ← × Pos NgRet
Eq        ← + Capital \+ × Capital Pnl
ShG       ← × √252 ÷ Std Pnl Mean Pnl
DdG       ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrG       ← × 100 ÷ Capital - Capital ⊣ Eq
ArG       ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnG       ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos

# ========== COMPARISON TABLE ==========
&p "Variant                     | Sharpe | MaxDD% | AnnRet% | TotRet% | Entries"
&p "----------------------------|--------|--------|---------|---------|-------"
&p ⊂ "A: No filter (baseline)     |  " ⊂ json Rnd ShA ⊂ " | " ⊂ json Rnd DdA ⊂ " | " ⊂ json Rnd ArA ⊂ " | " ⊂ json Rnd TrA ⊂ " | " json EnA
&p ⊂ "B: NG > $3.50               |  " ⊂ json Rnd ShB ⊂ " | " ⊂ json Rnd DdB ⊂ " | " ⊂ json Rnd ArB ⊂ " | " ⊂ json Rnd TrB ⊂ " | " json EnB
&p ⊂ "C: NG > 50d MA              |  " ⊂ json Rnd ShC ⊂ " | " ⊂ json Rnd DdC ⊂ " | " ⊂ json Rnd ArC ⊂ " | " ⊂ json Rnd TrC ⊂ " | " json EnC
&p ⊂ "D: 25% trailing stop        |  " ⊂ json Rnd ShD ⊂ " | " ⊂ json Rnd DdD ⊂ " | " ⊂ json Rnd ArD ⊂ " | " ⊂ json Rnd TrD ⊂ " | " json EnD
&p ⊂ "E: 15% trailing stop        |  " ⊂ json Rnd ShE ⊂ " | " ⊂ json Rnd DdE ⊂ " | " ⊂ json Rnd ArE ⊂ " | " ⊂ json Rnd TrE ⊂ " | " json EnE
&p ⊂ "F: NG>$3.50 + 25% stop     |  " ⊂ json Rnd ShF ⊂ " | " ⊂ json Rnd DdF ⊂ " | " ⊂ json Rnd ArF ⊂ " | " ⊂ json Rnd TrF ⊂ " | " json EnF
&p ⊂ "G: NG>$3.50 + 15% stop     |  " ⊂ json Rnd ShG ⊂ " | " ⊂ json Rnd DdG ⊂ " | " ⊂ json Rnd ArG ⊂ " | " ⊂ json Rnd TrG ⊂ " | " json EnG
