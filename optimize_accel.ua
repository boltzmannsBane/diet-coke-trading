# optimize_accel.ua — "Diet Coke HFT": second derivative trading
# Buy when price acceleration > 0 (curve bending up), flat when < 0
# Tests raw vs smoothed second derivative on NASDAQ

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
&p "║       DIET COKE HFT: SECOND DERIVATIVE TRADING             ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ⊂ "Records: " json ⧻ NqPrices
&p ""
&p "Signal: long when d²P/dt² > 0 (price curve bending upward)"
&p "        flat when d²P/dt² < 0 (price curve bending downward)"
&p ""

Capital ← 100000

# ========== VARIANT A: Buy-and-hold NASDAQ (baseline) ==========
Ret ← ÷ ↘ ¯1 NqPrices - ↘ ¯1 NqPrices ↘ 1 NqPrices
Pnl ← Ret
Eq  ← + Capital \+ × Capital Pnl
ShA ← × √252 ÷ Std Pnl Mean Pnl
DdA ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrA ← × 100 ÷ Capital - Capital ⊣ Eq
ArA ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnA ← 1
InA ← 100.00

# ========== VARIANT B: Raw 2nd derivative (no smoothing) ==========
Dff ← - ↘ ¯1 NqPrices ↘ 1 NqPrices
Acc ← - ↘ ¯1 Dff ↘ 1 Dff
Sig ← > 0 Acc
Pos ← ↘ ¯1 Sig
Tr  ← ↘ 2 NqPrices
Ret ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl ← × Pos Ret
Eq  ← + Capital \+ × Capital Pnl
ShB ← × √252 ÷ Std Pnl Mean Pnl
DdB ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrB ← × 100 ÷ Capital - Capital ⊣ Eq
ArB ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnB ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InB ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT C: 5-day smoothed ==========
Sm  ← ⧈(Mean) 5 NqPrices
Dff ← - ↘ ¯1 Sm ↘ 1 Sm
Acc ← - ↘ ¯1 Dff ↘ 1 Dff
Sig ← > 0 Acc
Pos ← ↘ ¯1 Sig
Tr  ← ↘ 6 NqPrices
Ret ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl ← × Pos Ret
Eq  ← + Capital \+ × Capital Pnl
ShC ← × √252 ÷ Std Pnl Mean Pnl
DdC ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrC ← × 100 ÷ Capital - Capital ⊣ Eq
ArC ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnC ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InC ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT D: 10-day smoothed ==========
Sm  ← ⧈(Mean) 10 NqPrices
Dff ← - ↘ ¯1 Sm ↘ 1 Sm
Acc ← - ↘ ¯1 Dff ↘ 1 Dff
Sig ← > 0 Acc
Pos ← ↘ ¯1 Sig
Tr  ← ↘ 11 NqPrices
Ret ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl ← × Pos Ret
Eq  ← + Capital \+ × Capital Pnl
ShD ← × √252 ÷ Std Pnl Mean Pnl
DdD ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrD ← × 100 ÷ Capital - Capital ⊣ Eq
ArD ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnD ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InD ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT E: 20-day smoothed ==========
Sm  ← ⧈(Mean) 20 NqPrices
Dff ← - ↘ ¯1 Sm ↘ 1 Sm
Acc ← - ↘ ¯1 Dff ↘ 1 Dff
Sig ← > 0 Acc
Pos ← ↘ ¯1 Sig
Tr  ← ↘ 21 NqPrices
Ret ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl ← × Pos Ret
Eq  ← + Capital \+ × Capital Pnl
ShE ← × √252 ÷ Std Pnl Mean Pnl
DdE ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrE ← × 100 ÷ Capital - Capital ⊣ Eq
ArE ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnE ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InE ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT F: 50-day smoothed ==========
Sm  ← ⧈(Mean) 50 NqPrices
Dff ← - ↘ ¯1 Sm ↘ 1 Sm
Acc ← - ↘ ¯1 Dff ↘ 1 Dff
Sig ← > 0 Acc
Pos ← ↘ ¯1 Sig
Tr  ← ↘ 51 NqPrices
Ret ← ÷ ↘ ¯1 Tr - ↘ ¯1 Tr ↘ 1 Tr
Pnl ← × Pos Ret
Eq  ← + Capital \+ × Capital Pnl
ShF ← × √252 ÷ Std Pnl Mean Pnl
DdF ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrF ← × 100 ÷ Capital - Capital ⊣ Eq
ArF ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnF ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InF ← × 100 ÷ ⧻ Pos /+ Pos

# ========== VARIANT G: Price > 200d MA (current Strategy 3) ==========
MAs  ← ⧈(Mean) 200 NqPrices
NqTr ← ↘ 199 NqPrices
Sig  ← > MAs NqTr
Ret  ← ÷ ↘ ¯1 NqTr - ↘ ¯1 NqTr ↘ 1 NqTr
Pos  ← ↘ ¯1 Sig
Pnl  ← × Pos Ret
Eq   ← + Capital \+ × Capital Pnl
ShG  ← × √252 ÷ Std Pnl Mean Pnl
DdG  ← × 100 /↥ ÷ \↥ Eq - Eq \↥ Eq
TrG  ← × 100 ÷ Capital - Capital ⊣ Eq
ArG  ← × 100 - 1 ⁿ ÷ ÷ 252 ⧻ Pnl 1 ÷ Capital ⊣ Eq
EnG  ← /+ × = 0 ↘ ¯1 Pos ≠ 0 ↘ 1 Pos
InG  ← × 100 ÷ ⧻ Pos /+ Pos

# ========== COMPARISON TABLE ==========
&p ""
&p "Variant                  | Sharpe | MaxDD% | AnnRet% | TotRet% | Switches | %In"
&p "-------------------------|--------|--------|---------|---------|---------  |----"
&p ⊂ "A: Buy & hold            |  " ⊂ json Rnd ShA ⊂ " | " ⊂ json Rnd DdA ⊂ " | " ⊂ json Rnd ArA ⊂ " | " ⊂ json Rnd TrA ⊂ " | " ⊂ json EnA ⊂ " | " json Rnd InA
&p ⊂ "B: Raw d²P (no smooth)   |  " ⊂ json Rnd ShB ⊂ " | " ⊂ json Rnd DdB ⊂ " | " ⊂ json Rnd ArB ⊂ " | " ⊂ json Rnd TrB ⊂ " | " ⊂ json EnB ⊂ " | " json Rnd InB
&p ⊂ "C: d²P, 5d smoothed      |  " ⊂ json Rnd ShC ⊂ " | " ⊂ json Rnd DdC ⊂ " | " ⊂ json Rnd ArC ⊂ " | " ⊂ json Rnd TrC ⊂ " | " ⊂ json EnC ⊂ " | " json Rnd InC
&p ⊂ "D: d²P, 10d smoothed     |  " ⊂ json Rnd ShD ⊂ " | " ⊂ json Rnd DdD ⊂ " | " ⊂ json Rnd ArD ⊂ " | " ⊂ json Rnd TrD ⊂ " | " ⊂ json EnD ⊂ " | " json Rnd InD
&p ⊂ "E: d²P, 20d smoothed     |  " ⊂ json Rnd ShE ⊂ " | " ⊂ json Rnd DdE ⊂ " | " ⊂ json Rnd ArE ⊂ " | " ⊂ json Rnd TrE ⊂ " | " ⊂ json EnE ⊂ " | " json Rnd InE
&p ⊂ "F: d²P, 50d smoothed     |  " ⊂ json Rnd ShF ⊂ " | " ⊂ json Rnd DdF ⊂ " | " ⊂ json Rnd ArF ⊂ " | " ⊂ json Rnd TrF ⊂ " | " ⊂ json EnF ⊂ " | " json Rnd InF
&p ⊂ "G: Price > 200d MA       |  " ⊂ json Rnd ShG ⊂ " | " ⊂ json Rnd DdG ⊂ " | " ⊂ json Rnd ArG ⊂ " | " ⊂ json Rnd TrG ⊂ " | " ⊂ json EnG ⊂ " | " json Rnd InG
