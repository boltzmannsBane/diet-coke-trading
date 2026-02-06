# Experimental!
# portfolio.ua — Multi-Strategy Portfolio Backtester
# 
# Strategy 1: NG/Crude ratio mean reversion (Variant G)
#   - 60d lookback, 2σ entry, 0.5σ exit
#   - 2-day momentum reversal + NG > $3.50 filter
#   - Trail 1.0σ + ratio 3.0σ double stop-loss
# 
# Strategy 2: NG Seasonal + $3.50 filter + 25% trailing stop
#   - Long NG from October through March (winter heating premium)
#   - Only enter when NG price > $3.50
#   - 25% trailing stop from peak NG price per winter season
# 
# Strategy 3: NASDAQ Trend-Following (Price > 200d MA)
#   - Long when NASDAQ price is above 200-day moving average
#   - Flat when below
# 
# Portfolio: equal allocation ($33.3k each), combined equity curve

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

&p "╔══════════════════════════════════════════════════════════════╗"
&p "║         MULTI-STRATEGY PORTFOLIO BACKTESTER                ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ""
&p "--- Loading Data ---"

ParseCsv "data/ng_daily.csv"
NgDates  ←
NgPrices ←
&p ⊂ "NG records:     " json ⧻ NgDates

ParseCsv "data/wti_daily.csv"
WtiDates  ←
WtiPrices ←
&p ⊂ "WTI records:    " json ⧻ WtiDates

ParseCsv "data/nasdaq_daily.csv"
NqDates  ←
NqPrices ←
&p ⊂ "NASDAQ records: " json ⧻ NqDates

# ============================================
# HELPERS
# ============================================
Mean ← ÷⊃⧻(/+)
Std  ← √ Mean ⁿ2 - Mean .
Rnd  ← ÷ 100 ⁅ × 100

UpdatePos ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⊙⊙.
  ⊙⊙⊙(=0)
  ⊃(× ⊙◌ ⊙⊙◌
  | × ¬ ◌ ⊙⊙⊙◌)
  +
)

FillFwd ← \(⨬(⋅∘|⊙◌) ≠0 .)
MinResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↧|⊙◌)
)
MaxResetFn ← (
  ⊃(⊡0 ⊙◌|⊡1 ⊙◌|⋅∘)
  ⨬(↥|⊙◌)
)

ExtractMonth ← ⋕ ↙2 ↘5 °□

# ============================================
# ALIGN ALL THREE DATASETS BY DATE
# ============================================
# NG ∩ WTI
NgInWti      ← ∊ WtiDates NgDates
AlignedDates ← ▽ NgInWti NgDates
AlignedNg    ← ▽ NgInWti NgPrices
WtiIdx       ← ⨂ WtiDates AlignedDates
AlignedWti   ← ⊏ WtiIdx WtiPrices

# (NG ∩ WTI) ∩ NASDAQ
NqInAll  ← ∊ NqDates AlignedDates
AllDates ← ▽ NqInAll AlignedDates
AllNg    ← ▽ NqInAll AlignedNg
AllWti   ← ▽ NqInAll AlignedWti
NqIdx    ← ⨂ NqDates AllDates
AllNq    ← ⊏ NqIdx NqPrices

&p ⊂ "Common dates:   " ⊂ json ⧻ AllDates ⊂ " (" ⊂ °□⊢ AllDates ⊂ " to " ⊂ °□⊣ AllDates ")"

# ============================================
# STRATEGY 1: NG/CRUDE RATIO MEAN REVERSION (Variant G)
# ============================================
&p ""
&p "══════════════════════════════════════════"
&p "  Strategy 1: NG/Crude Ratio (Variant G)"
&p "══════════════════════════════════════════"

Lb  ← 60
Thr ← 2.0

Ratio ← ÷ AllNg AllWti
RMn   ← ⧈(Mean) Lb Ratio
RSt   ← ⧈(Std) Lb Ratio
Off   ← - 1 Lb
TrR   ← ↘ Off Ratio
TrDt  ← ↘ Off AllDates
TrNg  ← ↘ Off AllNg
TrWti ← ↘ Off AllWti
UB    ← + RMn × Thr RSt
LBand ← - RMn × Thr RSt

RatioChg ← - ↘ ¯2 TrR ↘ 2 TrR
MomLen   ← ⧻ RatioChg
MomDrop  ← - MomLen ⧻ TrR
MR       ← ↘ MomDrop TrR
MDates   ← ↘ MomDrop TrDt
MNg      ← ↘ MomDrop TrNg
MWti     ← ↘ MomDrop TrWti
MUB      ← ↘ MomDrop UB
MLB      ← ↘ MomDrop LBand
MRMn     ← ↘ MomDrop RMn
MRSt     ← ↘ MomDrop RSt

# NG > $3.50 filter on long entries
RawLong  ← × > 3.5 MNg × < 0 RatioChg > MUB MR
RawShort ← × > 0 RatioChg < MLB MR
RawEntry ← - RawShort RawLong
NearMean ← < × 0.5 MRSt ⌵ - MRMn MR

SignalRows ← ≡⊟ NearMean RawEntry
PosOne     ← ∧(. UpdatePos) SignalRows 0

# Double stop-loss
BaseFlat    ← = 0 PosOne
PrPe        ← ⊂ 0 ↘ ¯1 PosOne
EntryDay    ← × = 0 PrPe ≠ 0 PosOne
DistFromMn  ← ⌵ - MRMn MR
MinDistRows ← ≡⊟ EntryDay DistFromMn
RunMinDist  ← ∧(. MinResetFn) MinDistRows ∞
TrailDist   ← - RunMinDist DistFromMn
TrailStop   ← × ≠ 0 PosOne > × 1.0 MRSt TrailDist
EntryVal    ← × EntryDay MR
EntryRatios ← FillFwd EntryVal
RatioDist   ← ⌵ - EntryRatios MR
RatioStop   ← × ≠ 0 PosOne > × 3.0 MRSt RatioDist
DblStop     ← ↥ TrailStop RatioStop
StopRows    ← ≡⊟ BaseFlat DblStop
Blocked     ← ∧(. UpdatePos) StopRows 0
ModPosOne   ← × PosOne ¬ Blocked

# Daily PnL for strategy 1
NgRetOne  ← ÷ ↘ ¯1 MNg - ↘ ¯1 MNg ↘ 1 MNg
WtiRetOne ← ÷ ↘ ¯1 MWti - ↘ ¯1 MWti ↘ 1 MWti
PfROne    ← ↘ ¯1 ModPosOne
PnlOne    ← × PfROne - WtiRetOne NgRetOne
# Dates for the return series (1 shorter than position arrays)
RetDates ← ↘ 1 MDates

&p ⊂ "  Bars:   " json ⧻ PnlOne
&p ⊂ "  Trades: " json /+ × = 0 ↘ ¯1 ModPosOne ≠ 0 ↘ 1 ModPosOne

# ============================================
# STRATEGY 2: NG SEASONAL + $3.50 FILTER + 25% TRAILING STOP
# ============================================
&p ""
&p "══════════════════════════════════════════"
&p "  Strategy 2: NG Seasonal (Filtered+Stop)"
&p "══════════════════════════════════════════"

# Extract month from each date
Months ← ≡ExtractMonth AllDates

# Winter = months 10,11,12,1,2,3 → long NG
# Summer = months 4,5,6,7,8,9 → flat
IsWinter ← ↥ ≥ 10 Months ≤ 3 Months

# Daily NG returns
NgRetAll ← ÷ ↘ ¯1 AllNg - ↘ ¯1 AllNg ↘ 1 AllNg

# Base position: long during winter (no lookahead)
BasePos ← ↘ ¯1 IsWinter
# NG prices aligned with returns
NgAlign ← ↘ 1 AllNg

# Entry days: first day of each winter season
PrevWin  ← ⊂ 0 ↘ ¯1 BasePos
WinEntry ← × BasePos = 0 PrevWin

# Track running peak NG price per winter (resets each entry)
PeakRows ← ≡⊟ WinEntry NgAlign
RunPeak  ← ∧(. MaxResetFn) PeakRows 0

# NG > $3.50 filter
NgFilt ← > 3.5 NgAlign

# 25% trailing stop: exit if price drops 25% from winter peak
StopTrig   ← × BasePos < × 0.75 RunPeak NgAlign
LatchRows  ← ≡⊟ WinEntry StopTrig
WinBlocked ← ∧(. MaxResetFn) LatchRows 0

# Final position: winter × $3.50 filter × not stopped
SeasonPosF ← × × NgFilt BasePos ¬ WinBlocked
PnlTwo     ← × SeasonPosF NgRetAll

&p ⊂ "  Bars (raw): " json ⧻ PnlTwo

# ============================================
# STRATEGY 3: NASDAQ TREND-FOLLOWING (Price > 200d MA)
# ============================================
&p ""
&p "══════════════════════════════════════════"
&p "  Strategy 3: NASDAQ Trend (>200d MA)"
&p "══════════════════════════════════════════"

# 200-day moving average on NASDAQ
MAslow ← ⧈(Mean) 200 AllNq

# Trim NASDAQ prices to match MA length
NqTrimmed ← ↘ 199 AllNq

# Trend signal: long when price > 200d MA
TrendSig ← > MAslow NqTrimmed

# NASDAQ daily returns
NqRetAll ← ÷ ↘ ¯1 NqTrimmed - ↘ ¯1 NqTrimmed ↘ 1 NqTrimmed
TrendPos ← ↘ ¯1 TrendSig
PnlThree ← × TrendPos NqRetAll

&p ⊂ "  Bars (raw): " json ⧻ PnlThree

# ============================================
# ALIGN ALL STRATEGIES TO COMMON DATE RANGE
# ============================================
# Strategy 3 starts latest (200-day MA lookback → AllDates[200])
# Trim Strategy 1 and 2 to match

# Strategy 1: PnlOne dates = AllDates[62:]
LateDt   ← ⊡ 200 AllDates
OneOff   ← ⨂ RetDates LateDt
PnlOneTr ← ↘ OneOff PnlOne

# Strategy 2: PnlTwo dates = AllDates[1:]
TwoOff   ← - 1 ⨂ AllDates LateDt
PnlTwoTr ← ↘ TwoOff PnlTwo

# Strategy 3: PnlThree dates = AllDates[200:], already aligned

# Common length (trim ends)
MinLen    ← ↧ ⧻ PnlOneTr ↧ ⧻ PnlTwoTr ⧻ PnlThree
PnlOneF   ← ↙ MinLen PnlOneTr
PnlTwoFn  ← ↙ MinLen PnlTwoTr
PnlThrFn  ← ↙ MinLen PnlThree
RetDatesF ← ↙ MinLen ↘ OneOff RetDates

# Trade counts for common period
WinterPosC ← ↙ MinLen ↘ TwoOff SeasonPosF
WinTrades  ← /+ × = 0 ↘ ¯1 WinterPosC ≠ 0 ↘ 1 WinterPosC
TrendPosC  ← ↙ MinLen TrendPos
TrTrades   ← /+ × = 0 ↘ ¯1 TrendPosC ≠ 0 ↘ 1 TrendPosC

&p ""
&p ⊂ "Common period: " ⊂ json MinLen ⊂ " bars (" ⊂ °□ ⊢ RetDatesF ⊂ " to " ⊂ °□ ⊣ RetDatesF ")"
&p ⊂ "  Winter entries: " json WinTrades
&p ⊂ "  Trend entries:  " json TrTrades

# ============================================
# INDIVIDUAL STRATEGY METRICS
# ============================================
&p ""
&p "══════════════════════════════════════════════════════════════════"
&p "  INDIVIDUAL STRATEGY RESULTS (each with $100k)"
&p "══════════════════════════════════════════════════════════════════"

Capital ← 100000
Alloc   ← ÷ 2 Capital

# --- Strategy 1 metrics ---
EqOne ← + Capital \+ × Alloc PnlOneF
ShOne ← × √252 ÷ Std PnlOneF Mean PnlOneF
PkOne ← \↥ EqOne
DdOne ← × 100 /↥ ÷ PkOne - EqOne PkOne
TrOne ← × 100 ÷ Capital - Capital ⊣ EqOne
ArOne ← × 100 - 1 ⁿ ÷ ÷ 252 MinLen 1 ÷ Capital ⊣ EqOne

&p ""
&p "  Strategy 1: NG/Crude Ratio Mean Reversion"
&p ⊂ "    Final equity:  $" json ⁅ ⊣ EqOne
&p ⊂ "    Total return:  " ⊂ json Rnd TrOne "%"
&p ⊂ "    Ann. return:   " ⊂ json Rnd ArOne "%"
&p ⊂ "    Max drawdown:  " ⊂ json Rnd DdOne "%"
&p ⊂ "    Sharpe:        " json Rnd ShOne

# --- Strategy 2 metrics ---
EqTwo ← + Capital \+ × Capital PnlTwoFn
ShTwo ← × √252 ÷ Std PnlTwoFn Mean PnlTwoFn
PkTwo ← \↥ EqTwo
DdTwo ← × 100 /↥ ÷ PkTwo - EqTwo PkTwo
TrTwo ← × 100 ÷ Capital - Capital ⊣ EqTwo
ArTwo ← × 100 - 1 ⁿ ÷ ÷ 252 MinLen 1 ÷ Capital ⊣ EqTwo

&p ""
&p "  Strategy 2: NG Seasonal (Filtered+Stop)"
&p ⊂ "    Final equity:  $" json ⁅ ⊣ EqTwo
&p ⊂ "    Total return:  " ⊂ json Rnd TrTwo "%"
&p ⊂ "    Ann. return:   " ⊂ json Rnd ArTwo "%"
&p ⊂ "    Max drawdown:  " ⊂ json Rnd DdTwo "%"
&p ⊂ "    Sharpe:        " json Rnd ShTwo

# --- Strategy 3 metrics ---
EqThree ← + Capital \+ × Capital PnlThrFn
ShThree ← × √252 ÷ Std PnlThrFn Mean PnlThrFn
PkThree ← \↥ EqThree
DdThree ← × 100 /↥ ÷ PkThree - EqThree PkThree
TrThree ← × 100 ÷ Capital - Capital ⊣ EqThree
ArThree ← × 100 - 1 ⁿ ÷ ÷ 252 MinLen 1 ÷ Capital ⊣ EqThree

&p ""
&p "  Strategy 3: NASDAQ Trend (>200d MA)"
&p ⊂ "    Final equity:  $" json ⁅ ⊣ EqThree
&p ⊂ "    Total return:  " ⊂ json Rnd TrThree "%"
&p ⊂ "    Ann. return:   " ⊂ json Rnd ArThree "%"
&p ⊂ "    Max drawdown:  " ⊂ json Rnd DdThree "%"
&p ⊂ "    Sharpe:        " json Rnd ShThree

# ============================================
# PORTFOLIO: EQUAL-WEIGHT COMBINATION
# ============================================
&p ""
&p "══════════════════════════════════════════════════════════════════"
&p "  EQUAL-WEIGHT PORTFOLIO ($33.3k each)"
&p "══════════════════════════════════════════════════════════════════"

PortAlloc ← ÷ 3 Capital
# Strategy 1 uses half-capital per leg (spread trade)
PnlPort ← + × PortAlloc PnlThrFn + × PortAlloc PnlTwoFn × ÷ 2 PortAlloc PnlOneF
EqPort  ← + Capital \+ PnlPort
ShPort  ← × √252 ÷ Std PnlPort Mean PnlPort
PkPort  ← \↥ EqPort
DdPort  ← × 100 /↥ ÷ PkPort - EqPort PkPort
TrPort  ← × 100 ÷ Capital - Capital ⊣ EqPort
ArPort  ← × 100 - 1 ⁿ ÷ ÷ 252 MinLen 1 ÷ Capital ⊣ EqPort

# Daily returns for correlation
DrOne   ← × ÷ 2 PortAlloc PnlOneF
DrTwo   ← × PortAlloc PnlTwoFn
DrThree ← × PortAlloc PnlThrFn

&p ""
&p ⊂ "  Final equity:     $" json ⁅ ⊣ EqPort
&p ⊂ "  Total return:     " ⊂ json Rnd TrPort "%"
&p ⊂ "  Annualized return:" ⊂ json Rnd ArPort "%"
&p ⊂ "  Max drawdown:     " ⊂ json Rnd DdPort "%"
&p ⊂ "  Sharpe ratio:     " json Rnd ShPort

# ============================================
# CORRELATION MATRIX
# ============================================
&p ""
&p "  Correlation Matrix (daily PnL):"

# Correlation = cov(X,Y) / (std(X) * std(Y))
# cov(X,Y) = mean(X*Y) - mean(X)*mean(Y)
CorrAB ← ÷ × Std DrOne Std DrTwo - × Mean DrOne Mean DrTwo Mean × DrOne DrTwo
CorrAC ← ÷ × Std DrOne Std DrThree - × Mean DrOne Mean DrThree Mean × DrOne DrThree
CorrBC ← ÷ × Std DrTwo Std DrThree - × Mean DrTwo Mean DrThree Mean × DrTwo DrThree

&p ⊂ "    Ratio vs Seasonal:  " json Rnd CorrAB
&p ⊂ "    Ratio vs NASDAQ:    " json Rnd CorrAC
&p ⊂ "    Seasonal vs NASDAQ: " json Rnd CorrBC

# ============================================
# SUMMARY BOX
# ============================================
&p ""
&p "╔══════════════════════════════════════════════════════════════════╗"
&p "║              PORTFOLIO PERFORMANCE SUMMARY                      ║"
&p "╠══════════════════════════════════════════════════════════════════╣"
&p ⊂ "║  Strategy 1 (NG/Crude):    Sharpe " ⊂ json Rnd ShOne ⊂ "  MaxDD " ⊂ json Rnd DdOne "%"
&p ⊂ "║  Strategy 2 (Seasonal+):   Sharpe " ⊂ json Rnd ShTwo ⊂ "  MaxDD " ⊂ json Rnd DdTwo "%"
&p ⊂ "║  Strategy 3 (NASDAQ TF):   Sharpe " ⊂ json Rnd ShThree ⊂ "  MaxDD " ⊂ json Rnd DdThree "%"
&p "║                                                                  ║"
&p ⊂ "║  PORTFOLIO (equal wt):     Sharpe " ⊂ json Rnd ShPort ⊂ "  MaxDD " ⊂ json Rnd DdPort "%"
&p "║                                                                  ║"
&p ⊂ "║  Correlations: 1-2: " ⊂ json Rnd CorrAB ⊂ "  1-3: " ⊂ json Rnd CorrAC ⊂ "  2-3: " json Rnd CorrBC
&p "╚══════════════════════════════════════════════════════════════════╝"

# --- Save outputs ---
&fwa "data/portfolio_equity.json" json EqPort
&fwa "data/portfolio_pnl.json" json PnlPort
&p ""
&p "Portfolio data saved to data/ directory."
