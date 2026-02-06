# Experimental!
# backtest.ua — Trade simulation engine
# Simulates spread trades with $100k starting capital
# Each leg gets 50% capital. PnL = percentage return × allocation.

# --- Configuration ---
StartingCapital ← 100000
LegAlloc        ← ÷ 2 StartingCapital

# --- Load strategy outputs ---
&p "=== Running Backtest ==="
Positions ← °json &fras "data/signals.json"
NgPrices  ← °json &fras "data/trimmed_ng.json"
WtiPrices ← °json &fras "data/trimmed_wti.json"
Dates     ← °json &fras "data/trimmed_dates.json"

N ← ⧻ Positions
&p N

# --- Daily percentage returns ---
# return[t] = (price[t] - price[t-1]) / price[t-1]
# ↘ ¯1 = drop last (all but last), ↘ 1 = drop first (all but first)
NgPrev ← ↘ ¯1 NgPrices
NgNext ← ↘ 1 NgPrices
NgRet  ← ÷ NgPrev - NgPrev NgNext

WtiPrev ← ↘ ¯1 WtiPrices
WtiNext ← ↘ 1 WtiPrices
WtiRet  ← ÷ WtiPrev - WtiPrev WtiNext

# Position for each return period (use prior bar's position, drop last)
PosForRet ← ↘ ¯1 Positions

# --- Daily PnL ---
# Long NG / Short WTI (position=1):
#   PnL = pos * LegAlloc * (NgRet - WtiRet)
# The spread PnL per bar
DailyPnl ← × PosForRet × LegAlloc - WtiRet NgRet

# --- Equity curve ---
Equity ← + StartingCapital \+ DailyPnl

&p "Daily PnL stats (mean / max / min):"
&p ÷⊃⧻(/+) DailyPnl
&p /↥ DailyPnl
&p /↧ DailyPnl

&p "Final equity:"
&p ⊣ Equity
&p "Total return %:"
&p × 100 ÷ StartingCapital - StartingCapital ⊣ Equity

# --- Trade counting ---
PrevPos ← ↘ ¯1 Positions
CurrPos ← ↘ 1 Positions
# Entry: was flat, now has position
Entries   ← × = 0 PrevPos ≠ 0 CurrPos
NumTrades ← /+ Entries
&p "Number of trades:"
&p NumTrades

# --- Show first few position changes ---
PosChanges ← ≠ PrevPos CurrPos
ChangeIdx  ← ⊚ PosChanges
TopIdx     ← ↙ 10 ChangeIdx
&p "=== First 10 Position Changes ==="
# Select dates and positions at change indices
ChDates ← ⊏ TopIdx Dates
ChPos   ← ⊏ TopIdx CurrPos
≡(
  &pf °□
  &pf " -> pos="
  &p json
) ChDates ChPos

# --- Save backtest results ---
&fwa "data/equity.json" json Equity
&fwa "data/daily_pnl.json" json DailyPnl
&p "=== Saved backtest results ==="
