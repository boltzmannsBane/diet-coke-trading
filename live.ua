# Experimental!
# live.ua — Daily Live Trading Simulation
# 
# Fetches today's prices from FRED API + CSV files, runs all 6 portfolio strategies,
# tracks positions/equity, logs trades, and emits events for frontend.
# Features: Grossman-Zhou drawdown control, quarterly rebalancing.
# 
# Usage: uiua run live.ua
# Run once per trading day (detects duplicate runs and exits early).

# ============================================
# SECTION 0: HELPERS
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
# SECTION 1: INITIALIZATION
# ============================================
&p "╔══════════════════════════════════════════════════════════════╗"
&p "║            LIVE TRADING SIMULATION                         ║"
&p "╚══════════════════════════════════════════════════════════════╝"
&p ""

InitAlloc ← 33333.33

# Check if state directory exists; initialize if needed
DoInit ← ¬ &fe "data/live/state.json"
⨬(&pf "[INIT] State files found.\n"
| &pf "[INIT] Creating data/live/ directory and initial state...\n"
  ⍣(◌&fmd|◌◌) "data/live" 0
  &fwa "data/live/state.json" json [200000 0 0 0 0]
  &fwa "data/live/strat_one.json" json [0 33333.33 0 0 0 33333.33]
  &fwa "data/live/strat_two.json" json [0 0 33333.33 0 0 0 33333.33 0]
  &fwa "data/live/strat_three.json" json [0 33333.33 0 0 0 33333.33]
  &fwa "data/live/strat_four.json" json [0 33333.33 0 0 0 33333.33]
  &fwa "data/live/strat_five.json" json [0 33333.33 0 0 0 33333.33]
  &fwa "data/live/strat_six.json" json [0 33333.33 0 0 0 33333.33]
  &fwa "data/live/trades_one.json" "[]"
  &fwa "data/live/trades_two.json" "[]"
  &fwa "data/live/trades_three.json" "[]"
  &fwa "data/live/trades_four.json" "[]"
  &fwa "data/live/trades_five.json" "[]"
  &fwa "data/live/trades_six.json" "[]"
  &fwa "data/live/equity.json" json [200000]
  &fwa "data/live/events.log" ""
  &fwa "data/live/commit" "0"
  &pf "[INIT] Done. Initial capital: $200,000\n"
) DoInit

# Load current state
GState ← °json &fras "data/live/state.json"
StratA ← °json &fras "data/live/strat_one.json"
StratB ← °json &fras "data/live/strat_two.json"
StratC ← °json &fras "data/live/strat_three.json"
StratD ← °json &fras "data/live/strat_four.json"
StratE ← °json &fras "data/live/strat_five.json"
StratF ← °json &fras "data/live/strat_six.json"
SeqNum ← ⊡1 GState
LastYr ← ⊡2 GState
LastMo ← ⊡3 GState
LastDy ← ⊡4 GState
&p ⊂ "[STATE] Seq=" ⊂ json SeqNum ⊂ " LastDate=" ⊂ json LastYr ⊂ "-" ⊂ json LastMo ⊂ "-" json LastDy

# ============================================
# SECTION 2: FETCH PRICES FROM FRED API
# ============================================
&p ""
&p "--- Fetching Prices from FRED ---"

# Inline FRED fetch: series_id → open socket, write request, read, parse
# Pattern for each: build request with $ heredoc, open TLS, write, read, close, extract body

# Fetch all 3 series from FRED at top level (avoid function body gotchas)
# NG (DHHNGSP)
&p "  Fetching NG (DHHNGSP)..."
$ GET /fred/series/observations?series_id=DHHNGSP&api_key=cc95b43cfab50c3b7103e7e2f2e64671&file_type=json&sort_order=desc&limit=5 HTTP/1.1
$ Host: api.stlouisfed.org
$ Connection: close
$ 
$ 
NgReq  ←
NgSock ← &tlsc "api.stlouisfed.org:443"
&w NgReq NgSock
NgResp ← &rs ∞ NgSock
&cl NgSock
NgBody   ← ↘ ˜⨂ @{ . StripCr NgResp
NgTokens ← ⊜□ ≠@" . NgBody
NgDate   ← °□ ⊡ + 2 ˜⨂ □"date" NgTokens NgTokens
NgVal    ← °□ ⊡ + 2 ˜⨂ □"value" NgTokens NgTokens
NgPrice  ← ⋕ NgVal
&p ⊂ "  [OK] NG=" ⊂ json NgPrice ⊂ " date=" NgDate

# WTI (DCOILWTICO)
&p "  Fetching WTI (DCOILWTICO)..."
$ GET /fred/series/observations?series_id=DCOILWTICO&api_key=cc95b43cfab50c3b7103e7e2f2e64671&file_type=json&sort_order=desc&limit=5 HTTP/1.1
$ Host: api.stlouisfed.org
$ Connection: close
$ 
$ 
WtiReq  ←
WtiSock ← &tlsc "api.stlouisfed.org:443"
&w WtiReq WtiSock
WtiResp ← &rs ∞ WtiSock
&cl WtiSock
WtiBody   ← ↘ ˜⨂ @{ . StripCr WtiResp
WtiTokens ← ⊜□ ≠@" . WtiBody
WtiDate   ← °□ ⊡ + 2 ˜⨂ □"date" WtiTokens WtiTokens
WtiVal    ← °□ ⊡ + 2 ˜⨂ □"value" WtiTokens WtiTokens
WtiPrice  ← ⋕ WtiVal
&p ⊂ "  [OK] WTI=" ⊂ json WtiPrice ⊂ " date=" WtiDate

# NASDAQ (NASDAQCOM)
&p "  Fetching NASDAQ (NASDAQCOM)..."
$ GET /fred/series/observations?series_id=NASDAQCOM&api_key=cc95b43cfab50c3b7103e7e2f2e64671&file_type=json&sort_order=desc&limit=5 HTTP/1.1
$ Host: api.stlouisfed.org
$ Connection: close
$ 
$ 
NqReq  ←
NqSock ← &tlsc "api.stlouisfed.org:443"
&w NqReq NqSock
NqResp ← &rs ∞ NqSock
&cl NqSock
NqBody   ← ↘ ˜⨂ @{ . StripCr NqResp
NqTokens ← ⊜□ ≠@" . NqBody
NqDate   ← °□ ⊡ + 2 ˜⨂ □"date" NqTokens NqTokens
NqVal    ← °□ ⊡ + 2 ˜⨂ □"value" NqTokens NqTokens
NqPrice  ← ⋕ NqVal
&p ⊂ "  [OK] NQ=" ⊂ json NqPrice ⊂ " date=" NqDate

# VIX (VIXCLS)
&p "  Fetching VIX (VIXCLS)..."
$ GET /fred/series/observations?series_id=VIXCLS&api_key=cc95b43cfab50c3b7103e7e2f2e64671&file_type=json&sort_order=desc&limit=5 HTTP/1.1
$ Host: api.stlouisfed.org
$ Connection: close
$ 
$ 
VixReq  ←
VixSock ← &tlsc "api.stlouisfed.org:443"
&w VixReq VixSock
VixResp ← &rs ∞ VixSock
&cl VixSock
VixBody   ← ↘ ˜⨂ @{ . StripCr VixResp
VixTokens ← ⊜□ ≠@" . VixBody
VixDate   ← °□ ⊡ + 2 ˜⨂ □"date" VixTokens VixTokens
VixVal    ← °□ ⊡ + 2 ˜⨂ □"value" VixTokens VixTokens
VixPrice  ← ⋕ VixVal
&p ⊂ "  [OK] VIX=" ⊂ json VixPrice ⊂ " date=" VixDate

# Load SVXY from CSV (refreshed by daemon before each run)
&p "  Loading SVXY from CSV..."
ParseCsv "data/svxy_daily.csv"
◌
SvxyPrice ← ⊣
&p ⊂ "  [OK] SVXY=" json SvxyPrice

# Load Gold from CSV (refreshed by daemon before each run)
&p "  Loading Gold from CSV..."
ParseCsv "data/gold_daily.csv"
◌
GoldPrice ← ⊣
&p ⊂ "  [OK] Gold=" json GoldPrice

# Load NANC from CSV (refreshed by daemon before each run)
&p "  Loading NANC from CSV..."
ParseCsv "data/nanc_daily.csv"
◌
NancPrice ← ⊣
&p ⊂ "  [OK] NANC=" json NancPrice

&p ""
&p ⊂ "[PRICE] NG=" ⊂ json NgPrice ⊂ " WTI=" ⊂ json WtiPrice ⊂ " NQ=" ⊂ json NqPrice ⊂ " VIX=" ⊂ json VixPrice ⊂ " SVXY=" ⊂ json SvxyPrice ⊂ " Gold=" ⊂ json GoldPrice ⊂ " NANC=" json NancPrice

# Use NG date as the reference date (all 3 FRED series update on the same day)
TodayDate ← NgDate
TodayYr   ← ⋕ ↙4 TodayDate
TodayMo   ← ⋕ ↙2 ↘5 TodayDate
TodayDy   ← ⋕ ↘8 TodayDate

# Check for duplicate run
IsDup ← × × = LastYr TodayYr = LastMo TodayMo = LastDy TodayDy
⍤ "Already ran today — exiting" ¬ IsDup

&p ⊂ "[LIVE] " ⊂ TodayDate ⊂ " SEQ=" json + 1 SeqNum

# ============================================
# SECTION 3: APPEND TO CSVs
# ============================================
&p ""
&p "--- Updating Historical CSVs ---"

# For now, we rely on the historical CSVs being up to date.
# The FRED API fetch gives us today's price for signal computation.
# CSV appending will be done in a future update when we need to grow
# the historical data files beyond what FRED provides.

# ============================================
# SECTION 4: RECOMPUTE SIGNALS FROM FULL HISTORY
# ============================================
&p ""
&p "--- Loading Historical Data & Computing Signals ---"

# Load all three datasets
ParseCsv "data/ng_daily.csv"
HNgDates  ←
HNgPrices ←
&p ⊂ "  NG records:     " json ⧻ HNgDates

ParseCsv "data/wti_daily.csv"
HWtiDates  ←
HWtiPrices ←
&p ⊂ "  WTI records:    " json ⧻ HWtiDates

ParseCsv "data/nasdaq_daily.csv"
HNqDates  ←
HNqPrices ←
&p ⊂ "  NASDAQ records: " json ⧻ HNqDates

ParseCsv "data/vix_daily.csv"
HVixDates  ←
HVixPrices ←
&p ⊂ "  VIX records:    " json ⧻ HVixDates

# --- Align all three datasets by date ---
# NG ∩ WTI
HNgInWti ← ∊ HWtiDates HNgDates
HAlDates ← ▽ HNgInWti HNgDates
HAlNg    ← ▽ HNgInWti HNgPrices
HWtiIdx  ← ⨂ HWtiDates HAlDates
HAlWti   ← ⊏ HWtiIdx HWtiPrices

# (NG ∩ WTI) ∩ NASDAQ
HNqInAll ← ∊ HNqDates HAlDates
AlBDt    ← ▽ HNqInAll HAlDates
AlBNg    ← ▽ HNqInAll HAlNg
AlBWti   ← ▽ HNqInAll HAlWti
HNqIdx   ← ⨂ HNqDates AlBDt
AlBNq    ← ⊏ HNqIdx HNqPrices

# (NG ∩ WTI ∩ NQ) ∩ VIX
HVxInAll ← ∊ HVixDates AlBDt
AllDt    ← ▽ HVxInAll AlBDt
AllNg    ← ▽ HVxInAll AlBNg
AllWti   ← ▽ HVxInAll AlBWti
AllNq    ← ▽ HVxInAll AlBNq
HVxIdx   ← ⨂ HVixDates AllDt
AllVix   ← ⊏ HVxIdx HVixPrices

# Load SVXY and align to AllDt (fill-forward for missing dates)
ParseCsv "data/svxy_daily.csv"
HSvxyDates  ←
HSvxyPrices ←
&p ⊂ "  SVXY records:   " json ⧻ HSvxyDates

# Load Gold and align to AllDt
ParseCsv "data/gold_daily.csv"
HGoldDates  ←
HGoldPrices ←
&p ⊂ "  Gold records:   " json ⧻ HGoldDates

# Align SVXY to AllDt using index-of with fill-forward
# ⨂ returns ⧻ HSvxyDates for dates not found — clamp to last valid index
HSvxyIdx ← ⨂ HSvxyDates AllDt
SvxyLen  ← ⧻ HSvxyPrices
# Replace out-of-bounds indices with 0 (will get price 0 = no data)
# Then fill forward so missing dates get the previous day's price
RawSvxy ← ⊏ ↧ - 1 SvxyLen HSvxyIdx HSvxyPrices
# Zero out entries before SVXY data starts (pre Oct 2011)
MskSvxy ← × < SvxyLen HSvxyIdx RawSvxy
AllSvxy ← FillFwd MskSvxy

# Align Gold to AllDt (same pattern)
HGoldIdx ← ⨂ HGoldDates AllDt
GoldLen  ← ⧻ HGoldPrices
RawGold  ← ⊏ ↧ - 1 GoldLen HGoldIdx HGoldPrices
MskGold  ← × < GoldLen HGoldIdx RawGold
AllGold  ← FillFwd MskGold

&p ⊂ "  Aligned bars:   " json ⧻ AllDt

# ============================================
# STRATEGY 1: PELOSI TRACKER (NANC > 50d MA)
# ============================================
# --- OLD S1: Ratio MR (preserved) ---
# Lb  ← 60
# Thr ← 2.0
# Ratio ← ÷ AllNg AllWti
# RMn   ← ⧈(Mean) Lb Ratio
# RSt   ← ⧈(Std) Lb Ratio
# Off   ← - 1 Lb
# TrR   ← ↘ Off Ratio
# UB    ← + RMn × Thr RSt
# LBd   ← - RMn × Thr RSt
# RatioChg ← - ↘ ¯2 TrR ↘ 2 TrR
# MomLen   ← ⧻ RatioChg
# MomDrop  ← - MomLen ⧻ TrR
# MR       ← ↘ MomDrop TrR
# MNg      ← ↘ MomDrop (↘ Off AllNg)
# MUB      ← ↘ MomDrop UB
# MLB      ← ↘ MomDrop LBd
# MRMn     ← ↘ MomDrop RMn
# MRSt     ← ↘ MomDrop RSt
# RawLong  ← × > 3.5 MNg × < 0 RatioChg > MUB MR
# RawShort ← × > 0 RatioChg < MLB MR
# RawEntry ← - RawShort RawLong
# NearMean ← < × 0.5 MRSt ⌵ - MRMn MR
# SigRowsA ← ≡⊟ NearMean RawEntry
# PosA     ← ∧(. UpdatePos) SigRowsA 0
# BaseFlatA   ← = 0 PosA
# PrPeA       ← ⊂ 0 ↘ ¯1 PosA
# EntryDayA   ← × = 0 PrPeA ≠ 0 PosA
# DistFmMnA   ← ⌵ - MRMn MR
# MinDistRwA  ← ≡⊟ EntryDayA DistFmMnA
# RunMinDistA ← ∧(. MinResetFn) MinDistRwA ∞
# TrailDistA  ← - RunMinDistA DistFmMnA
# TrailStopA  ← × ≠ 0 PosA > × 1.0 MRSt TrailDistA
# EntryValA   ← × EntryDayA MR
# EntryRatA   ← FillFwd EntryValA
# RatioDistA  ← ⌵ - EntryRatA MR
# RatioStopA  ← × ≠ 0 PosA > × 3.0 MRSt RatioDistA
# DblStopA    ← ↥ TrailStopA RatioStopA
# StopRwA     ← ≡⊟ BaseFlatA DblStopA
# BlockedA    ← ∧(. UpdatePos) StopRwA 0
# ModPosA     ← × PosA ¬ BlockedA
# TodaySigA ← ⊣ ModPosA
# --- END OLD S1 ---

# Load NANC history and align to AllDt (fill-forward for missing dates)
ParseCsv "data/nanc_daily.csv"
HNancDates  ←
HNancPrices ←
&p ⊂ "  NANC records:   " json ⧻ HNancDates

# Align NANC to AllDt (same pattern as SVXY/Gold)
HNancIdx ← ⨂ HNancDates AllDt
NancLen  ← ⧻ HNancPrices
RawNanc  ← ⊏ ↧ - 1 NancLen HNancIdx HNancPrices
MskNanc  ← × < NancLen HNancIdx RawNanc
AllNanc  ← FillFwd MskNanc

# 50d MA trend signal (50d because NANC only has ~750 days of data)
NancMA    ← ⧈(Mean) 50 AllNanc
NancTrimA ← ↘ 49 AllNanc
NancSigA  ← × ≠ 0 NancTrimA > NancMA NancTrimA
NancPosA  ← ↘ ¯1 NancSigA

TodaySigA ← ⊣ NancPosA
PrevPosA  ← ⊡0 StratA

&p ⊂ "  Strat1 signal: " ⊂ json TodaySigA ⊂ " (prev=" ⊂ json PrevPosA ")"

# ============================================
# STRATEGY 2: NG Seasonal + $3.50 filter + 25% trailing stop
# ============================================
Months ← ≡ExtractMonth AllDt

IsWinter ← ↥ ≥ 10 Months ≤ 3 Months

NgRetAll ← ÷ ↘ ¯1 AllNg - ↘ ¯1 AllNg ↘ 1 AllNg

BasePosB ← ↘ ¯1 IsWinter
NgAlignB ← ↘ 1 AllNg

PrevWinB  ← ⊂ 0 ↘ ¯1 BasePosB
WinEntryB ← × BasePosB = 0 PrevWinB

PeakRwB  ← ≡⊟ WinEntryB NgAlignB
RunPeakB ← ∧(. MaxResetFn) PeakRwB 0

NgFiltB ← > 3.5 NgAlignB

StopTrigB   ← × BasePosB < × 0.75 RunPeakB NgAlignB
LatchRwB    ← ≡⊟ WinEntryB StopTrigB
WinBlockedB ← ∧(. MaxResetFn) LatchRwB 0

SeasonPosB ← × × NgFiltB BasePosB ¬ WinBlockedB

TodaySigB ← ⊣ SeasonPosB
PrevPosB  ← ⊡0 StratB

&p ⊂ "  Strat2 signal: " ⊂ json TodaySigB ⊂ " (prev=" ⊂ json PrevPosB ")"

# ============================================
# STRATEGY 3: NASDAQ Trend-Following (Price > 200d MA)
# ============================================
MAslow ← ⧈(Mean) 200 AllNq

NqTrimC   ← ↘ 199 AllNq
VixTrimC  ← ↘ 199 AllVix
TrendSigC ← × < 30 VixTrimC > MAslow NqTrimC
TrendPosC ← ↘ ¯1 TrendSigC

TodaySigC ← ⊣ TrendPosC
PrevPosC  ← ⊡0 StratC

&p ⊂ "  Strat3 signal: " ⊂ json TodaySigC ⊂ " (prev=" ⊂ json PrevPosC ")"

# ============================================
# STRATEGY 4: SHORT VOL (Variance Risk Premium)
# ============================================
# 60d rolling mean of VIX
VixMnD ← ⧈(Mean) 60 AllVix

# 20d realized vol of NASDAQ: std of daily returns × √252 × 100
NqRetD ← ÷ ↘ ¯1 AllNq - ↘ ¯1 AllNq ↘ 1 AllNq
RVolD  ← × 100 × √252 ⧈(Std) 20 NqRetD

# Align: VixMnD starts at index 59, RVolD starts at index 20
# For the final signal, use the later start (59)
# VixMnD[i] → AllVix[i+59]; RVolD[i] → NqRetD[i+19] → AllNq[i+20]
# At aligned index k: VixMnD index = k-59, RVolD index = k-20

VixTrimD ← ↘ 59 AllVix
VmTrimD  ← VixMnD
# RVolD index for VixTrimD[i] = AllVix[i+59]: rVolIdx = (i+59) - 20 = i + 39
RvTrimD ← ↘ 39 RVolD
# Now trim all to same length (min of VixTrimD and RvTrimD)
MinLenD ← ↧ ⧻ VixTrimD ⧻ RvTrimD
VixSlD  ← ↙ MinLenD VixTrimD
VmSlD   ← ↙ MinLenD VmTrimD
RvSlD   ← ↙ MinLenD RvTrimD

# Signal: short when VIX > 60d mean AND VIX > realized vol AND VIX > 15
# Emergency stop: flat when VIX > 40
AboveMnD  ← > VmSlD VixSlD
AboveRvD  ← > RvSlD VixSlD
AboveFlrD ← > 15 VixSlD
BelowCapD ← < 40 VixSlD
ShortSigD ← × BelowCapD × AboveFlrD × AboveRvD AboveMnD
# pos = +1 when long SVXY, 0 when flat
VolPosD ← ShortSigD

TodaySigD ← ⊣ VolPosD
PrevPosD  ← ⊡0 StratD

&p ⊂ "  Strat4 signal: " ⊂ json TodaySigD ⊂ " (prev=" ⊂ json PrevPosD ")"

# ============================================
# STRATEGY 5: LINREG SLOPE (Diet Coke HFT, W=200 daily)
# ============================================
# LinReg slope: m = (n·ΣXY - ΣX·ΣY) / (n·ΣX² - (ΣX)²)
LrW     ← 200
SumXV   ← ÷ 2 × LrW - 1 LrW
SumXSV  ← ÷ 6 × LrW × - 1 LrW - 1 × 2 LrW
DenomV  ← - ⁿ 2 SumXV × LrW SumXSV
RollXYE ← ⧈(/+ × ⇡ LrW) LrW AllNq
RollYE  ← ⧈(/+) LrW AllNq
SlopeE  ← ÷ DenomV - × SumXV RollYE × LrW RollXYE
SigE    ← > 0 SlopeE
LrPosE  ← ↘ ¯1 SigE

TodaySigE ← ⊣ LrPosE
PrevPosE  ← ⊡0 StratE

&p ⊂ "  Strat5 signal: " ⊂ json TodaySigE ⊂ " (prev=" ⊂ json PrevPosE ")"

# ============================================
# STRATEGY 6: GOLD TREND-FOLLOWING (Gold > 200d MA)
# ============================================
GoldMA    ← ⧈(Mean) 200 AllGold
GoldTrimF ← ↘ 199 AllGold
GoldSigF  ← × ≠ 0 GoldTrimF > GoldMA GoldTrimF
GoldPosF  ← ↘ ¯1 GoldSigF

TodaySigF ← ⊣ GoldPosF
PrevPosF  ← ⊡0 StratF

&p ⊂ "  Strat6 signal: " ⊂ json TodaySigF ⊂ " (prev=" ⊂ json PrevPosF ")"

# ============================================
# SECTION 5: POSITION CHANGES & PnL
# ============================================
&p ""
&p "--- Computing PnL & Position Changes ---"

# --- Grossman-Zhou drawdown control ---
OldEqArr ← °json &fras "data/live/equity.json"
PeakEq   ← /↥ OldEqArr
CurEqGz  ← ⊣ OldEqArr
DtFrac   ← ⨬(0|÷ PeakEq - CurEqGz PeakEq) > 0 PeakEq
GzScale  ← ↥ 0 - ÷ 0.20 DtFrac 1
&p ⊂ "  [GZ] peak=" ⊂ json Rnd PeakEq ⊂ " dt=" ⊂ json Rnd DtFrac ⊂ " scale=" json Rnd GzScale

# Previous prices from state
PrevNancA ← ⊡3 StratA
PrevNgB   ← ⊡4 StratB
PrevNqC   ← ⊡3 StratC
PrevSvxyD ← ⊡3 StratD
PrevNqE   ← ⊡3 StratE
PrevGoldF ← ⊡3 StratF

# --- Quarterly rebalancing ---
NewSeq    ← + 1 SeqNum
NeedRebal ← × > 0 GzScale = 0 ◿ 63 NewSeq
# Current total equity = sum of all 6 strategy equities
CurTotRb   ← + + + + + ⊡5 StratA ⊡6 StratB ⊡5 StratC ⊡5 StratD ⊡5 StratE ⊡5 StratF
RebalAlloc ← ÷ 6 CurTotRb

# --- Strategy 1 PnL ---
# Long NANC when NANC > 50d MA, flat otherwise
AllocA ← ⨬(⊡1 StratA|RebalAlloc) NeedRebal
EqA    ← ⊡5 StratA
# Only compute PnL if we have previous NANC price
PnlA ← ⨬(
  0
| × GzScale × AllocA × PrevPosA ÷ PrevNancA - PrevNancA NancPrice
) ≠ 0 PrevNancA

NewEqA ← + EqA PnlA

# Trade tracking for Strat 1
ChgA       ← - PrevPosA TodaySigA
NewTcA     ← + ⊡4 StratA × ≠ 0 ChgA ≠ 0 TodaySigA
NewCumPnlA ← + ⊡2 StratA PnlA

# Build new strat 1 state: [pos, alloc, cumPnl, nancPrice, trades, eq]
NewStratA ← [TodaySigA AllocA NewCumPnlA NancPrice NewTcA NewEqA]

&p ⊂ "  Strat1: pos=" ⊂ json TodaySigA ⊂ " pnl=" ⊂ json Rnd PnlA ⊂ " eq=" json Rnd NewEqA

# --- Strategy 2 PnL ---
# Long NG only, with GzScale
AllocB ← ⨬(⊡2 StratB|RebalAlloc) NeedRebal
EqB    ← ⊡6 StratB
PnlB ← ⨬(
  0
| × GzScale × AllocB × PrevPosB ÷ PrevNgB - PrevNgB NgPrice
) ≠ 0 PrevNgB

NewEqB ← + EqB PnlB

ChgB       ← - PrevPosB TodaySigB
NewTcB     ← + ⊡5 StratB × ≠ 0 ChgB ≠ 0 TodaySigB
NewCumPnlB ← + ⊡3 StratB PnlB
# Peak NG for trailing stop: reset on new entry, otherwise carry forward
PeakBase ← ⨬(⊡1 StratB|NgPrice) = 0 × ≠ 0 ChgB ≠ 0 TodaySigB
NewPeakB ← ↥ PeakBase × TodaySigB NgPrice

NewStratB ← [TodaySigB NewPeakB AllocB NewCumPnlB NgPrice NewTcB NewEqB 0]

&p ⊂ "  Strat2: pos=" ⊂ json TodaySigB ⊂ " pnl=" ⊂ json Rnd PnlB ⊂ " eq=" json Rnd NewEqB

# --- Strategy 3 PnL ---
# Long NASDAQ only (VIX < 30 filter), with GzScale
AllocC ← ⨬(⊡1 StratC|RebalAlloc) NeedRebal
EqC    ← ⊡5 StratC
PnlC ← ⨬(
  0
| × GzScale × AllocC × PrevPosC ÷ PrevNqC - PrevNqC NqPrice
) ≠ 0 PrevNqC

NewEqC ← + EqC PnlC

ChgC       ← - PrevPosC TodaySigC
NewTcC     ← + ⊡4 StratC × ≠ 0 ChgC ≠ 0 TodaySigC
NewCumPnlC ← + ⊡2 StratC PnlC

NewStratC ← [TodaySigC AllocC NewCumPnlC NqPrice NewTcC NewEqC]

&p ⊂ "  Strat3: pos=" ⊂ json TodaySigC ⊂ " pnl=" ⊂ json Rnd PnlC ⊂ " eq=" json Rnd NewEqC

# --- Strategy 4 PnL ---
# Long SVXY: pnl = pos × svxy_return × alloc × gzScale
AllocD ← ⨬(⊡1 StratD|RebalAlloc) NeedRebal
EqD    ← ⊡5 StratD
PnlD ← ⨬(
  0
| × GzScale × AllocD × PrevPosD ÷ PrevSvxyD - PrevSvxyD SvxyPrice
) ≠ 0 PrevSvxyD

NewEqD ← + EqD PnlD

ChgD       ← - PrevPosD TodaySigD
NewTcD     ← + ⊡4 StratD × ≠ 0 ChgD ≠ 0 TodaySigD
NewCumPnlD ← + ⊡2 StratD PnlD

NewStratD ← [TodaySigD AllocD NewCumPnlD SvxyPrice NewTcD NewEqD]

&p ⊂ "  Strat4: pos=" ⊂ json TodaySigD ⊂ " pnl=" ⊂ json Rnd PnlD ⊂ " eq=" json Rnd NewEqD

# --- Strategy 5 PnL ---
# Long NASDAQ when LinReg slope > 0, with GzScale
AllocE ← ⨬(⊡1 StratE|RebalAlloc) NeedRebal
EqE    ← ⊡5 StratE
PnlE ← ⨬(
  0
| × GzScale × AllocE × PrevPosE ÷ PrevNqE - PrevNqE NqPrice
) ≠ 0 PrevNqE

NewEqE ← + EqE PnlE

ChgE       ← - PrevPosE TodaySigE
NewTcE     ← + ⊡4 StratE × ≠ 0 ChgE ≠ 0 TodaySigE
NewCumPnlE ← + ⊡2 StratE PnlE

NewStratE ← [TodaySigE AllocE NewCumPnlE NqPrice NewTcE NewEqE]

&p ⊂ "  Strat5: pos=" ⊂ json TodaySigE ⊂ " pnl=" ⊂ json Rnd PnlE ⊂ " eq=" json Rnd NewEqE

# --- Strategy 6 PnL ---
# Long Gold when price > 200d MA, with GzScale
AllocF ← ⨬(⊡1 StratF|RebalAlloc) NeedRebal
EqF    ← ⊡5 StratF
PnlF ← ⨬(
  0
| × GzScale × AllocF × PrevPosF ÷ PrevGoldF - PrevGoldF GoldPrice
) ≠ 0 PrevGoldF

NewEqF ← + EqF PnlF

ChgF       ← - PrevPosF TodaySigF
NewTcF     ← + ⊡4 StratF × ≠ 0 ChgF ≠ 0 TodaySigF
NewCumPnlF ← + ⊡2 StratF PnlF

NewStratF ← [TodaySigF AllocF NewCumPnlF GoldPrice NewTcF NewEqF]

&p ⊂ "  Strat6: pos=" ⊂ json TodaySigF ⊂ " pnl=" ⊂ json Rnd PnlF ⊂ " eq=" json Rnd NewEqF

# --- Portfolio totals ---
TotalEq  ← + + + + + NewEqA NewEqB NewEqC NewEqD NewEqE NewEqF
TotalPnl ← + + + + + PnlA PnlB PnlC PnlD PnlE PnlF

# Drawdown from peak (OldEqArr already loaded above for Grossman-Zhou)
CurDD ← × 100 ÷ ↥ PeakEq TotalEq - ↥ PeakEq TotalEq TotalEq

&p ""
&p ⊂ "[PORTFOLIO] equity=" ⊂ json Rnd TotalEq ⊂ " pnl=" ⊂ json Rnd TotalPnl ⊂ " dd=" ⊂ json Rnd CurDD "%" ⊂ " gz=" json Rnd GzScale

# ============================================
# SECTION 6: WRITE PHASE
# ============================================
&p ""
&p "--- Writing State ---"

# Write strategy states
&fwa "data/live/strat_one.json" json NewStratA
&fwa "data/live/strat_two.json" json NewStratB
&fwa "data/live/strat_three.json" json NewStratC
&fwa "data/live/strat_four.json" json NewStratD
&fwa "data/live/strat_five.json" json NewStratE
&fwa "data/live/strat_six.json" json NewStratF

# Update trade logs for any position changes
# Strategy 1 trade log (Pelosi Tracker / NANC)
TradesAStr ← &fras "data/live/trades_one.json"
⨬(&fwa "data/live/trades_one.json" TradesAStr
| ⨬(&p ⊂ "[TRADE] strat=1 ENTRY LONG nanc=" json NancPrice
    &fwa "data/live/trades_one.json" ⊂ TradesAStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 NancPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=1 EXIT pos=" json PrevPosA
    &fwa "data/live/trades_one.json" ⊂ TradesAStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 NancPrice PrevPosA PnlA]
  ) = 0 TodaySigA
) ≠ 0 ChgA

# Strategy 2 trade log
TradesBStr ← &fras "data/live/trades_two.json"
⨬(&fwa "data/live/trades_two.json" TradesBStr
| ⨬(&p ⊂ "[TRADE] strat=2 ENTRY LONG price=" json NgPrice
    &fwa "data/live/trades_two.json" ⊂ TradesBStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 NgPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=2 EXIT pos=" json PrevPosB
    &fwa "data/live/trades_two.json" ⊂ TradesBStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 NgPrice PrevPosB PnlB]
  ) = 0 TodaySigB
) ≠ 0 ChgB

# Strategy 3 trade log
TradesCStr ← &fras "data/live/trades_three.json"
⨬(&fwa "data/live/trades_three.json" TradesCStr
| ⨬(&p ⊂ "[TRADE] strat=3 ENTRY LONG price=" json NqPrice
    &fwa "data/live/trades_three.json" ⊂ TradesCStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 NqPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=3 EXIT pos=" json PrevPosC
    &fwa "data/live/trades_three.json" ⊂ TradesCStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 NqPrice PrevPosC PnlC]
  ) = 0 TodaySigC
) ≠ 0 ChgC

# Strategy 4 trade log (long SVXY)
TradesDStr ← &fras "data/live/trades_four.json"
⨬(&fwa "data/live/trades_four.json" TradesDStr
| ⨬(&p ⊂ "[TRADE] strat=4 ENTRY LONG svxy=" json SvxyPrice
    &fwa "data/live/trades_four.json" ⊂ TradesDStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 SvxyPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=4 EXIT pos=" json PrevPosD
    &fwa "data/live/trades_four.json" ⊂ TradesDStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 SvxyPrice PrevPosD PnlD]
  ) = 0 TodaySigD
) ≠ 0 ChgD

# Strategy 5 trade log
TradesEStr ← &fras "data/live/trades_five.json"
⨬(&fwa "data/live/trades_five.json" TradesEStr
| ⨬(&p ⊂ "[TRADE] strat=5 ENTRY LONG price=" json NqPrice
    &fwa "data/live/trades_five.json" ⊂ TradesEStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 NqPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=5 EXIT pos=" json PrevPosE
    &fwa "data/live/trades_five.json" ⊂ TradesEStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 NqPrice PrevPosE PnlE]
  ) = 0 TodaySigE
) ≠ 0 ChgE

# Strategy 6 trade log (gold trend)
TradesFStr ← &fras "data/live/trades_six.json"
⨬(&fwa "data/live/trades_six.json" TradesFStr
| ⨬(&p ⊂ "[TRADE] strat=6 ENTRY LONG gold=" json GoldPrice
    &fwa "data/live/trades_six.json" ⊂ TradesFStr ⊂ "\n" json [TodayYr TodayMo TodayDy 0 0 0 GoldPrice 0 1 0]
  | &p ⊂ "[TRADE] strat=6 EXIT pos=" json PrevPosF
    &fwa "data/live/trades_six.json" ⊂ TradesFStr ⊂ "\n" json [0 0 0 TodayYr TodayMo TodayDy 0 GoldPrice PrevPosF PnlF]
  ) = 0 TodaySigF
) ≠ 0 ChgF

# Append to equity time series
NewEqArr ← ⊂ OldEqArr [TotalEq]
&fwa "data/live/equity.json" json NewEqArr

# Write global state (second to last)
NewGState ← [TotalEq NewSeq TodayYr TodayMo TodayDy]
&fwa "data/live/state.json" json NewGState

# Write commit file LAST (write barrier)
&fwa "data/live/commit" json NewSeq

&p ⊂ "  [OK] State written, seq=" json NewSeq

# ============================================
# SECTION 7: EVENTS & SUMMARY
# ============================================
&p ""

# Append to events.log
OldEvents ← &fras "data/live/events.log"
EvSeq     ← json NewSeq
EvDate    ← TodayDate

# Build event lines
EvPrice  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|PRICE|NG=" ⊂ json NgPrice ⊂ "|WTI=" ⊂ json WtiPrice ⊂ "|NQ=" ⊂ json NqPrice ⊂ "|VIX=" ⊂ json VixPrice ⊂ "|SVXY=" ⊂ json SvxyPrice ⊂ "|Gold=" ⊂ json GoldPrice ⊂ "|NANC=" json NancPrice
EvEquity ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|EQUITY|" json Rnd TotalEq
EvStOne  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|1|pos=" ⊂ json TodaySigA ⊂ "|eq=" json Rnd NewEqA
EvStTwo  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|2|pos=" ⊂ json TodaySigB ⊂ "|eq=" json Rnd NewEqB
EvStThr  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|3|pos=" ⊂ json TodaySigC ⊂ "|eq=" json Rnd NewEqC
EvStFou  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|4|pos=" ⊂ json TodaySigD ⊂ "|eq=" json Rnd NewEqD
EvStFiv  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|5|pos=" ⊂ json TodaySigE ⊂ "|eq=" json Rnd NewEqE
EvStSix  ← ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|STRAT|6|pos=" ⊂ json TodaySigF ⊂ "|eq=" json Rnd NewEqF

BaseEvents ← ⊂ OldEvents ⊂ EvPrice ⊂ "\n" ⊂ EvEquity ⊂ "\n" ⊂ EvStOne ⊂ "\n" ⊂ EvStTwo ⊂ "\n" ⊂ EvStThr ⊂ "\n" ⊂ EvStFou ⊂ "\n" ⊂ EvStFiv ⊂ "\n" ⊂ EvStSix "\n"

# Add GZ/REBAL events
EvGzRb ← ⨬(BaseEvents|⊂ BaseEvents ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|GZ|scale=" ⊂ json Rnd GzScale "\n") < 1 GzScale
EvRb   ← ⨬(EvGzRb|⊂ EvGzRb ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|REBAL|alloc=" ⊂ json Rnd RebalAlloc "\n") NeedRebal

# Add trade events if any
EvWithA   ← ⨬(EvRb|⊂ EvRb ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|1|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigA ⊂ "|" ⊂ json NancPrice "\n") ≠ 0 ChgA
EvWithB   ← ⨬(EvWithA|⊂ EvWithA ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|2|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigB ⊂ "|" ⊂ json NgPrice "\n") ≠ 0 ChgB
EvWithC   ← ⨬(EvWithB|⊂ EvWithB ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|3|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigC ⊂ "|" ⊂ json NqPrice "\n") ≠ 0 ChgC
EvWithD   ← ⨬(EvWithC|⊂ EvWithC ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|4|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigD ⊂ "|" ⊂ json SvxyPrice "\n") ≠ 0 ChgD
EvWithE   ← ⨬(EvWithD|⊂ EvWithD ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|5|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigE ⊂ "|" ⊂ json NqPrice "\n") ≠ 0 ChgE
NewEvents ← ⨬(EvWithE|⊂ EvWithE ⊂ EvSeq ⊂ "|" ⊂ EvDate ⊂ "|TRADE|6|" ⊂ ⨬("ENTRY"|"EXIT") = 0 TodaySigF ⊂ "|" ⊂ json GoldPrice "\n") ≠ 0 ChgF

&fwa "data/live/events.log" NewEvents

# Print summary box
&p "╔══════════════════════════════════════════════════════════════╗"
&p "║            LIVE TRADING SUMMARY                            ║"
&p "╠══════════════════════════════════════════════════════════════╣"
&p ⊂ "║  Date:       " TodayDate
&p ⊂ "║  Sequence:   " json NewSeq
&p ⊂ "║  NG Price:   $" json NgPrice
&p ⊂ "║  WTI Price:  $" json WtiPrice
&p ⊂ "║  NQ Price:   " json NqPrice
&p ⊂ "║  VIX:        " json VixPrice
&p ⊂ "║  SVXY:       $" json SvxyPrice
&p ⊂ "║  Gold:       $" json GoldPrice
&p ⊂ "║  NANC:       $" json NancPrice
&p "║                                                            ║"
&p ⊂ "║  Strat 1 (Pelosi):   pos=" ⊂ json TodaySigA ⊂ "  eq=$" json Rnd NewEqA
&p ⊂ "║  Strat 2 (Seasonal): pos=" ⊂ json TodaySigB ⊂ "  eq=$" json Rnd NewEqB
&p ⊂ "║  Strat 3 (NQ+VIX):   pos=" ⊂ json TodaySigC ⊂ "  eq=$" json Rnd NewEqC
&p ⊂ "║  Strat 4 (SVXY):     pos=" ⊂ json TodaySigD ⊂ "  eq=$" json Rnd NewEqD
&p ⊂ "║  Strat 5 (LinReg):   pos=" ⊂ json TodaySigE ⊂ "  eq=$" json Rnd NewEqE
&p ⊂ "║  Strat 6 (Gold):     pos=" ⊂ json TodaySigF ⊂ "  eq=$" json Rnd NewEqF
&p "║                                                            ║"
&p ⊂ "║  GZ Scale:   " json Rnd GzScale
PortLine ← ⊂ "║  PORTFOLIO:  $" ⊂ json Rnd TotalEq ⊂ "  PnL: $" json Rnd TotalPnl
&p ⊂ PortLine ⊂ "  DD: " ⊂ json Rnd CurDD "%"
&p "╚══════════════════════════════════════════════════════════════╝"
