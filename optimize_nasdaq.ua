# optimize_nasdaq.ua — NASDAQ trend signal optimization
# Tests faster MA crossover and single-MA signals

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

ParseCsv "data/nasdaq_daily.csv"
NqDates  ←
NqPrices ←

&p "╔══════════════════════════════════════════════════════════════╗"
&p "║         NASDAQ TREND SIGNAL OPTIMIZATION                   ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ⊂ "Records: " json ⧻ NqPrices
&p ""

Capital ← 100000

# ========== VARIANT A: 50/200 MA Crossover (baseline) ==========
MAfRaw ← ⧈(Mean) 50 NqPrices
MAs    ← ⧈(Mean) 200 NqPrices
MAf    ← ↘ 150 MAfRaw
Sig    ← > MAs MAf
NqTr   ← ↘ 199 NqPrices
Ret    ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos    ← ↘ ¯1 Sig
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShA    ← × √252 ÷ Std Pnl Mean Pnl
DdA    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrA    ← × 100 ÷ Capital - Capital ⊣ Eq
ArA    ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnA    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InA    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT B: 20/100 MA Crossover ==========
MAfRaw ← ⧈(Mean) 20 NqPrices
MAs    ← ⧈(Mean) 100 NqPrices
MAf    ← ↘ 80 MAfRaw
Sig    ← > MAs MAf
NqTr   ← ↘ 99 NqPrices
Ret    ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos    ← ↘ ¯1 Sig
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShB    ← × √252 ÷ Std Pnl Mean Pnl
DdB    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrB    ← × 100 ÷ Capital - Capital ⊣ Eq
ArB    ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnB    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InB    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT C: 10/50 MA Crossover ==========
MAfRaw ← ⧈(Mean) 10 NqPrices
MAs    ← ⧈(Mean) 50 NqPrices
MAf    ← ↘ 40 MAfRaw
Sig    ← > MAs MAf
NqTr   ← ↘ 49 NqPrices
Ret    ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos    ← ↘ ¯1 Sig
Pnl    ← × Pos Ret
Eq     ← + Capital \+ × Capital Pnl
ShC    ← × √252 ÷ Std Pnl Mean Pnl
DdC    ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrC    ← × 100 ÷ Capital - Capital ⊣ Eq
ArC    ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnC    ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InC    ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT D: Price > 200d SMA ==========
MAs  ← ⧈(Mean) 200 NqPrices
NqTr ← ↘ 199 NqPrices
Sig  ← > MAs NqTr
Ret  ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos  ← ↘ ¯1 Sig
Pnl  ← × Pos Ret
Eq   ← + Capital \+ × Capital Pnl
ShD  ← × √252 ÷ Std Pnl Mean Pnl
DdD  ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrD  ← × 100 ÷ Capital - Capital ⊣ Eq
ArD  ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnD  ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InD  ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT E: Price > 100d SMA ==========
MAs  ← ⧈(Mean) 100 NqPrices
NqTr ← ↘ 99 NqPrices
Sig  ← > MAs NqTr
Ret  ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos  ← ↘ ¯1 Sig
Pnl  ← × Pos Ret
Eq   ← + Capital \+ × Capital Pnl
ShE  ← × √252 ÷ Std Pnl Mean Pnl
DdE  ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrE  ← × 100 ÷ Capital - Capital ⊣ Eq
ArE  ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnE  ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InE  ← × 100 ÷ ⧻ Pos /+ Pos

# ========== COMPARISON TABLE ==========
&p "Variant              | Sharpe | MaxDD% | AnnRet% | TotRet% | Sw | %In"
&p "---------------------|--------|--------|---------|---------|----|----|"
&p ⊂ "A: 50/200 MA cross   |  " ⊂ json Rnd ShA ⊂ " | " ⊂ json Rnd DdA ⊂ " | " ⊂ json Rnd ArA ⊂ " | " ⊂ json Rnd TrA ⊂ " | " ⊂ json EnA ⊂ " | " json Rnd InA
&p ⊂ "B: 20/100 MA cross   |  " ⊂ json Rnd ShB ⊂ " | " ⊂ json Rnd DdB ⊂ " | " ⊂ json Rnd ArB ⊂ " | " ⊂ json Rnd TrB ⊂ " | " ⊂ json EnB ⊂ " | " json Rnd InB
&p ⊂ "C: 10/50 MA cross    |  " ⊂ json Rnd ShC ⊂ " | " ⊂ json Rnd DdC ⊂ " | " ⊂ json Rnd ArC ⊂ " | " ⊂ json Rnd TrC ⊂ " | " ⊂ json EnC ⊂ " | " json Rnd InC
&p ⊂ "D: Price > 200d MA   |  " ⊂ json Rnd ShD ⊂ " | " ⊂ json Rnd DdD ⊂ " | " ⊂ json Rnd ArD ⊂ " | " ⊂ json Rnd TrD ⊂ " | " ⊂ json EnD ⊂ " | " json Rnd InD
&p ⊂ "E: Price > 100d MA   |  " ⊂ json Rnd ShE ⊂ " | " ⊂ json Rnd DdE ⊂ " | " ⊂ json Rnd ArE ⊂ " | " ⊂ json Rnd TrE ⊂ " | " ⊂ json EnE ⊂ " | " json Rnd InE
