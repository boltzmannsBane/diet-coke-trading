# metrics.ua — Performance metrics for the backtest
# Computes: total return, annualized return, max drawdown,
# Sharpe ratio, win rate, trade count, avg trade duration

# --- Statistical helpers ---
Mean ← ÷⊃⧻(/+)
Std  ← √ Mean ⁿ2 - Mean .

# --- Load backtest results ---
&p "=== Performance Metrics ==="
Equity    ← °json &fras "data/equity.json"
DailyPnl  ← °json &fras "data/daily_pnl.json"
Positions ← °json &fras "data/signals.json"
Dates     ← °json &fras "data/trimmed_dates.json"

StartingCapital ← 100000
FinalEquity     ← ⊣ Equity
N               ← ⧻ DailyPnl

# --- Total Return ---
TotalReturn ← × 100 ÷ StartingCapital - StartingCapital FinalEquity
&p "Total Return (%):"
&p TotalReturn

# --- Annualized Return ---
# ~252 trading days per year
Years ← ÷ 252 N
# Annualized = ((final/initial)^(1/years) - 1) * 100
AnnReturn ← × 100 - 1 ⁿ ÷ Years 1 ÷ StartingCapital FinalEquity
&p "Annualized Return (%):"
&p AnnReturn
&p "Years:"
&p Years

# --- Max Drawdown ---
# Peak equity at each point
Peak ← \↥ Equity
# Drawdown = (peak - equity) / peak
Drawdown    ← ÷ Peak - Equity Peak
MaxDrawdown ← × 100 /↥ Drawdown
&p "Max Drawdown (%):"
&p MaxDrawdown

# --- Sharpe Ratio ---
# Annualized: (mean daily return / std daily return) * sqrt(252)
DailyRet ← ÷ ↘ ¯1 Equity - ↘ ¯1 Equity ↘ 1 Equity
MeanRet  ← Mean DailyRet
StdRet   ← Std DailyRet
Sharpe   ← × √252 ÷ StdRet MeanRet
&p "Sharpe Ratio:"
&p Sharpe

# --- Win Rate ---
# Percentage of profitable trading days (when in a position)
InPosition  ← ≠ 0 ↘ ¯1 Positions
ActivePnl   ← ▽ InPosition DailyPnl
WinDays     ← /+ > 0 ActivePnl
TotalActive ← ⧻ ActivePnl
WinRate     ← × 100 ÷ TotalActive WinDays
&p "Win Rate (% of active days):"
&p WinRate
&p "Active trading days:"
&p TotalActive

# --- Number of Trades ---
PrevPos   ← ↘ ¯1 Positions
CurrPos   ← ↘ 1 Positions
Entries   ← × = 0 PrevPos ≠ 0 CurrPos
NumTrades ← /+ Entries
&p "Number of trades:"
&p NumTrades

# --- Average Trade Duration ---
# Count consecutive days in position per trade
# Number of days in position / number of trades
DaysInPos   ← /+ ≠ 0 Positions
AvgDuration ← ÷ NumTrades DaysInPos
&p "Avg trade duration (days):"
&p AvgDuration

# --- Profit Factor ---
GrossProfit  ← /+ ▽ > 0 ActivePnl ActivePnl
GrossLoss    ← /+ ▽ < 0 ActivePnl ActivePnl
ProfitFactor ← ÷ ⌵ GrossLoss GrossProfit
&p "Profit Factor:"
&p ProfitFactor

# --- Summary Table ---
&p ""
&p "╔══════════════════════════════════════╗"
&p "║   BACKTEST PERFORMANCE SUMMARY      ║"
&p "╠══════════════════════════════════════╣"
# Round to 2 decimal places
Rnd ← ÷ 100 ⁅ × 100
&p ⊂ "║  Total Return:      " ⊂ json Rnd TotalReturn "%"
&p ⊂ "║  Annualized Return: " ⊂ json Rnd AnnReturn "%"
&p ⊂ "║  Max Drawdown:      " ⊂ json Rnd MaxDrawdown "%"
&p ⊂ "║  Sharpe Ratio:      " json Rnd Sharpe
&p ⊂ "║  Win Rate:          " ⊂ json Rnd WinRate "%"
&p ⊂ "║  Trades:            " json NumTrades
&p ⊂ "║  Avg Duration:      " ⊂ json Rnd AvgDuration " days"
&p ⊂ "║  Profit Factor:     " json Rnd ProfitFactor
&p "╚══════════════════════════════════════╝"
