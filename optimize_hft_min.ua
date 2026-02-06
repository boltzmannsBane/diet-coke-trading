# optimize_hft_min.ua — LinReg on 1-minute NAS100 data (2017-2018)
# Includes bull run (2017-Oct 2018) and Q4 2018 crash (-23%)

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

# ~341k bars/year (24hr CFD, ~1350 bars/day × 252 trading days)
Bpy ← 340000

ParseCsv "data/nas_minute.csv"
Dates  ←
Prices ←

&p "╔══════════════════════════════════════════════════════════════╗"
&p "║   DIET COKE HFT v3: LINEAR REGRESSION ON 1-MINUTE DATA     ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ⊂ "NAS100 1-min bars: " json ⧻ Prices
&p ⊂ "Period: " ⊂ °□ ⊢ Dates ⊂ " to " °□ ⊣ Dates
&p ""

Capital ← 100000

# ========== VARIANT A: Buy & hold (baseline) ==========
Ret ← ÷ ↘ ¯1 Prices - ↘ ¯1 Prices ↘ 1 Prices
Pnl ← Ret
Eq  ← + Capital \+ × Capital Pnl
ShA ← × √Bpy ÷ Std Pnl Mean Pnl
DdA ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrA ← × 100 ÷ Capital - Capital ⊣ Eq
ArA ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnA ← 1

# ========== VARIANT B: LinReg W=10 (10 min) ==========
&p "Computing W=10..."
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
ShB    ← × √Bpy ÷ Std Pnl Mean Pnl
DdB    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrB    ← × 100 ÷ Capital - Capital ⊣ Eq
ArB    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnB    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InB    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT C: LinReg W=50 (~1 hour) ==========
&p "Computing W=50..."
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
ShC    ← × √Bpy ÷ Std Pnl Mean Pnl
DdC    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrC    ← × 100 ÷ Capital - Capital ⊣ Eq
ArC    ← × 100 - 1 ⁿ ÷ ÷ Bpy ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnC    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InC    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT D: LinReg W=200 (~3.3 hours) ==========
&p "Computing W=200..."
W      ← 200
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

# ========== VARIANT E: LinReg W=500 (~8 hours, ~1 trading day) ==========
&p "Computing W=500..."
W      ← 500
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

# ========== VARIANT F: LinReg W=3000 (~50 hours, ~1 week) ==========
&p "Computing W=3000..."
W      ← 3000
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

# ========== COMPARISON TABLE ==========
&p ""
&p "Variant                   | Sharpe | MaxDD% | AnnRet% | TotRet% | Trades"
&p "--------------------------|--------|--------|---------|---------| ------"
&p ⊂ "A: Buy & hold             |  " ⊂ json Rnd ShA ⊂ " | " ⊂ json Rnd DdA ⊂ " | " ⊂ json Rnd ArA ⊂ " | " ⊂ json Rnd TrA ⊂ " | " json EnA
&p ⊂ "B: LinReg W=10 (10min)    |  " ⊂ json Rnd ShB ⊂ " | " ⊂ json Rnd DdB ⊂ " | " ⊂ json Rnd ArB ⊂ " | " ⊂ json Rnd TrB ⊂ " | " json EnB
&p ⊂ "C: LinReg W=50 (1hr)      |  " ⊂ json Rnd ShC ⊂ " | " ⊂ json Rnd DdC ⊂ " | " ⊂ json Rnd ArC ⊂ " | " ⊂ json Rnd TrC ⊂ " | " json EnC
&p ⊂ "D: LinReg W=200 (3hr)     |  " ⊂ json Rnd ShD ⊂ " | " ⊂ json Rnd DdD ⊂ " | " ⊂ json Rnd ArD ⊂ " | " ⊂ json Rnd TrD ⊂ " | " json EnD
&p ⊂ "E: LinReg W=500 (8hr)     |  " ⊂ json Rnd ShE ⊂ " | " ⊂ json Rnd DdE ⊂ " | " ⊂ json Rnd ArE ⊂ " | " ⊂ json Rnd TrE ⊂ " | " json EnE
&p ⊂ "F: LinReg W=3000 (1wk)    |  " ⊂ json Rnd ShF ⊂ " | " ⊂ json Rnd DdF ⊂ " | " ⊂ json Rnd ArF ⊂ " | " ⊂ json Rnd TrF ⊂ " | " json EnF
&p ""
&p "Note: NAS100 CFD data (Oanda), not exchange data."
&p "Period includes 2017 bull run + 2018 Q4 crash (-23%)."
