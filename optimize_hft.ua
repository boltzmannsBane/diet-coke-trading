# optimize_hft.ua — "Diet Coke HFT" v2: Linear Regression on Hourly Data
# Fit linear regression over rolling window, long when slope > 0
# Data: QQQ hourly bars from Twelve Data API

StripCr    ← ▽ ≠@\r .
HasPrice   ← > 1 ⧻ ⊜□ ≠@, . °□
ParseDate  ← °□⊢ ⊜□ ≠@, . °□
ParsePrice ← ⋕°□⊡1 ⊜□ ≠@, . °□
ParseCsv ← (
  ↘1 ⊜□ ≠@\n . StripCr &fras
  ▽ ≡HasPrice .
  ⊃(≡ParseDate|≡ParsePrice)
)
Mean ← ÷⊃⧻(/+)
Std  ← √ Mean ⁿ2 - Mean .
Rnd  ← ÷ 100 ⁅ × 100

# Annualization: 7 bars/day × 252 trading days = 1764 bars/year
Bpy ← 1764

ParseCsv "data/qqq_hourly.csv"
Dates  ←
Prices ←

&p "╔══════════════════════════════════════════════════════════════╗"
&p "║     DIET COKE HFT v2: LINEAR REGRESSION ON HOURLY DATA     ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ⊂ "QQQ hourly bars: " json ⧻ Prices
&p ⊂ "Period: " ⊂ °□ ⊢ Dates ⊂ " to " °□ ⊣ Dates
&p ""
&p "For each bar, fit y = mx + b over last W bars."
&p "Long when slope m > 0 (uptrend), flat when m <= 0."
&p ""

Capital ← 100000

# ========== VARIANT A: Buy & hold QQQ (baseline) ==========
Ret ← ÷ ↘ ¯1 Prices - ↘ ¯1 Prices ↘ 1 Prices
Pnl ← Ret
Eq  ← + Capital \+ × Capital Pnl
ShA ← × √Bpy ÷ Std Pnl Mean Pnl
DdA ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrA ← × 100 ÷ Capital - Capital ⊣ Eq
ArA ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnA ← 1
InA ← 100.00

# ========== VARIANT B: LinReg W=5 (~0.7 days) ==========
W      ← 5
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
Sig    ← > 0 Slope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ - 1 W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShB    ← × √Bpy ÷ Std Pnl Mean Pnl
DdB    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrB    ← × 100 ÷ Capital - Capital ⊣ Eq
ArB    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnB    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InB    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT C: LinReg W=10 (~1.4 days) ==========
W      ← 10
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
Sig    ← > 0 Slope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ - 1 W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShC    ← × √Bpy ÷ Std Pnl Mean Pnl
DdC    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrC    ← × 100 ÷ Capital - Capital ⊣ Eq
ArC    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnC    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InC    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT D: LinReg W=20 (~3 days) ==========
W      ← 20
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
Sig    ← > 0 Slope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ - 1 W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShD    ← × √Bpy ÷ Std Pnl Mean Pnl
DdD    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrD    ← × 100 ÷ Capital - Capital ⊣ Eq
ArD    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnD    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InD    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT E: LinReg W=50 (~1 week) ==========
W      ← 50
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
Sig    ← > 0 Slope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ - 1 W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShE    ← × √Bpy ÷ Std Pnl Mean Pnl
DdE    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrE    ← × 100 ÷ Capital - Capital ⊣ Eq
ArE    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnE    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InE    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT F: LinReg W=100 (~2 weeks) ==========
W      ← 100
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
Sig    ← > 0 Slope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ - 1 W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShF    ← × √Bpy ÷ Std Pnl Mean Pnl
DdF    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrF    ← × 100 ÷ Capital - Capital ⊣ Eq
ArF    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnF    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InF    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT G: Acceleration (change in slope), W=20 ==========
W      ← 20
SumXV  ← ÷ 2 × W - 1 W
SumXSV ← ÷ 6 × W × - 1 W - 1 × 2 W
DenomV ← - ⁿ 2 SumXV × W SumXSV
RollXY ← ⧈(/+ × ⇡ W) W Prices
RollY  ← ⧈(/+) W Prices
Slope  ← ÷ DenomV - × SumXV RollY × W RollXY
# Second derivative: change in slope
DSlope ← - ↘ ¯1 Slope ↘ 1 Slope
Sig    ← > 0 DSlope
Pos    ← ↘ ¯1 Sig
Tr     ← ↘ W Prices
Ret    ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShG    ← × √Bpy ÷ Std Pnl Mean Pnl
DdG    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrG    ← × 100 ÷ Capital - Capital ⊣ Eq
ArG    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnG    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InG    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== COMPARISON TABLE ==========
&p ""
&p "Variant                   | Sharpe | MaxDD% | AnnRet% | TotRet% | Trades | %In"
&p "--------------------------|--------|--------|---------|---------| -------|----"
&p ⊂ "A: Buy & hold             |  " ⊂ json Rnd ShA ⊂ " | " ⊂ json Rnd DdA ⊂ " | " ⊂ json Rnd ArA ⊂ " | " ⊂ json Rnd TrA ⊂ " | " ⊂ json EnA ⊂ " | " json Rnd InA
&p ⊂ "B: LinReg W=5 (0.7d)      |  " ⊂ json Rnd ShB ⊂ " | " ⊂ json Rnd DdB ⊂ " | " ⊂ json Rnd ArB ⊂ " | " ⊂ json Rnd TrB ⊂ " | " ⊂ json EnB ⊂ " | " json Rnd InB
&p ⊂ "C: LinReg W=10 (1.4d)     |  " ⊂ json Rnd ShC ⊂ " | " ⊂ json Rnd DdC ⊂ " | " ⊂ json Rnd ArC ⊂ " | " ⊂ json Rnd TrC ⊂ " | " ⊂ json EnC ⊂ " | " json Rnd InC
&p ⊂ "D: LinReg W=20 (3d)       |  " ⊂ json Rnd ShD ⊂ " | " ⊂ json Rnd DdD ⊂ " | " ⊂ json Rnd ArD ⊂ " | " ⊂ json Rnd TrD ⊂ " | " ⊂ json EnD ⊂ " | " json Rnd InD
&p ⊂ "E: LinReg W=50 (1wk)      |  " ⊂ json Rnd ShE ⊂ " | " ⊂ json Rnd DdE ⊂ " | " ⊂ json Rnd ArE ⊂ " | " ⊂ json Rnd TrE ⊂ " | " ⊂ json EnE ⊂ " | " json Rnd InE
&p ⊂ "F: LinReg W=100 (2wk)     |  " ⊂ json Rnd ShF ⊂ " | " ⊂ json Rnd DdF ⊂ " | " ⊂ json Rnd ArF ⊂ " | " ⊂ json Rnd TrF ⊂ " | " ⊂ json EnF ⊂ " | " json Rnd InF
&p ⊂ "G: Accel (dSlope) W=20    |  " ⊂ json Rnd ShG ⊂ " | " ⊂ json Rnd DdG ⊂ " | " ⊂ json Rnd ArG ⊂ " | " ⊂ json Rnd TrG ⊂ " | " ⊂ json EnG ⊂ " | " json Rnd InG
