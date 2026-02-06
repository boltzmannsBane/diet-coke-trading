"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import type { AppData, LogEvent } from "@/lib/types";
import { fetchAppData, fetchCommit } from "@/lib/data";

const POLL_INTERVAL = 30_000;
const NUM_STRATEGIES = 6;

const fmtUsd = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
});

const fmtNum = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

function pnlColor(v: number) {
  if (v > 0) return "text-profit";
  if (v < 0) return "text-loss";
  return "text-secondary";
}

function posLabel(pos: number) {
  if (pos === 1) return { text: "LONG", cls: "text-profit" };
  if (pos === -1) return { text: "SHORT", cls: "text-loss" };
  return { text: "FLAT", cls: "text-muted" };
}

/* ── Metrics helpers ───────────────────────────────── */

function computeSharpe(equity: number[]): number {
  if (equity.length < 3) return 0;
  const returns: number[] = [];
  for (let i = 1; i < equity.length; i++) {
    returns.push((equity[i] - equity[i - 1]) / equity[i - 1]);
  }
  const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
  const variance =
    returns.reduce((a, b) => a + (b - mean) ** 2, 0) / returns.length;
  const std = Math.sqrt(variance);
  if (std === 0) return 0;
  return (mean / std) * Math.sqrt(252);
}

function computeMaxDrawdown(equity: number[]): number {
  if (equity.length < 2) return 0;
  let peak = equity[0];
  let maxDD = 0;
  for (let i = 1; i < equity.length; i++) {
    if (equity[i] > peak) peak = equity[i];
    const dd = (peak - equity[i]) / peak;
    if (dd > maxDD) maxDD = dd;
  }
  return maxDD * 100;
}

/* ── Strategy colors ───────────────────────────────── */

const STRAT_COLORS: Record<string, string> = {
  "1": "#ef4444", // red
  "2": "#22c55e", // green
  "3": "#eab308", // yellow
  "4": "#a855f7", // purple
  "5": "#f97316", // orange
  "6": "#06b6d4", // cyan
};

/* ── Header ─────────────────────────────────────────── */

function Header({ date, seq }: { date: string; seq: number }) {
  return (
    <div className="flex items-center justify-between mb-6">
      <div className="flex items-center gap-3">
        <img
          src="/web/out/dietcoke.svg"
          alt=""
          className="w-10 h-10"
        />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            Diet Coke Trading
          </h1>
          <p className="text-secondary text-sm mt-1">
            Multi-strategy portfolio &middot; Live simulation
          </p>
        </div>
      </div>
      <div className="text-right text-sm text-secondary">
        <div className="flex items-center justify-end gap-2">
          <span className="live-pulse inline-block w-2 h-2 rounded-full bg-profit" />
          <span className="text-profit text-xs font-bold tracking-wider">LIVE</span>
        </div>
        <div className="mt-1">{date}</div>
        <div className="text-muted">Day {seq}</div>
      </div>
    </div>
  );
}

/* ── Balance Bar ────────────────────────────────────── */

function BalanceBar({ capital, pnl }: { capital: number; pnl: number }) {
  return (
    <div className="border border-subtle p-5 mb-6">
      <div className="flex items-end justify-between">
        <div>
          <div className="text-secondary text-xs uppercase tracking-wider mb-1">
            Portfolio Value
          </div>
          <div className="text-3xl font-bold">{fmtUsd.format(capital)}</div>
        </div>
        <div className="text-right">
          <div className="text-secondary text-xs uppercase tracking-wider mb-1">
            Total P&amp;L
          </div>
          <div className={`text-xl font-semibold ${pnlColor(pnl)}`}>
            {pnl >= 0 ? "+" : ""}
            {fmtUsd.format(pnl)}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ── Trade Ticker ───────────────────────────────────── */

const STRAT_SHORT: Record<string, string> = {
  "1": "Pelosi",
  "2": "NG Seasonal",
  "3": "NQ Trend",
  "4": "SVXY Vol",
  "5": "LinReg",
  "6": "Gold Trend",
};

function TickerItem({ ev }: { ev: LogEvent }) {
  const strat = STRAT_SHORT[ev.details[0]] ?? `S${ev.details[0]}`;
  const action = ev.details[1];
  const val = ev.details[2];
  const isEntry = action === "ENTRY";
  const actionCls = isEntry ? "text-profit" : "text-loss";
  return (
    <span>
      <span className="text-ticker">{ev.date}  {strat} </span>
      <span className={actionCls}>{isEntry ? "\u25B2" : "\u25BC"} {action}</span>
      <span className="text-ticker"> @ {val}</span>
    </span>
  );
}

function TradeTicker({ events }: { events: LogEvent[] }) {
  const trades = events
    .filter((e) => e.type === "TRADE")
    .slice(-20)
    .reverse();

  if (trades.length === 0) return null;

  const sep = <span className="text-muted mx-6">&middot;</span>;

  const renderItems = () =>
    trades.map((ev, i) => (
      <span key={i}>
        <TickerItem ev={ev} />
        {sep}
      </span>
    ));

  return (
    <div className="ticker-bar w-full overflow-hidden border-b border-subtle bg-[#0d1220]">
      <div
        className="ticker-track whitespace-nowrap py-3 text-sm font-mono"
        style={{
          animation: `ticker-scroll ${Math.max(trades.length * 6, 30)}s linear infinite`,
          width: "max-content",
        }}
      >
        {renderItems()}
        {renderItems()}
      </div>
    </div>
  );
}

/* ── Strategy Card ──────────────────────────────────── */

function StratCard({
  id,
  title,
  subtitle,
  pos,
  eq,
  pnl,
  trades,
  sharpe,
  maxDD,
  extra,
  active,
  onClick,
}: {
  id: string;
  title: string;
  subtitle: string;
  pos: number;
  eq: number;
  pnl: number;
  trades: number;
  sharpe: number;
  maxDD: number;
  extra?: { label: string; value: string }[];
  active: boolean;
  onClick: () => void;
}) {
  const p = posLabel(pos);
  const color = STRAT_COLORS[id];
  return (
    <div
      className={`border p-5 cursor-pointer transition-all ${
        active
          ? "border-foreground/40 bg-[#151d30]"
          : "border-subtle hover:border-subtle/80"
      }`}
      onClick={onClick}
    >
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-2">
          <div
            className="w-2.5 h-2.5 rounded-full shrink-0"
            style={{ backgroundColor: active ? color : "#505a6e" }}
          />
          <div>
            <div className="font-semibold">{title}</div>
            <div className="text-secondary text-xs mt-0.5">{subtitle}</div>
          </div>
        </div>
        <span
          className={`${p.cls} text-xs font-bold border px-2 py-0.5 ${
            pos === 1
              ? "border-profit/30"
              : pos === -1
                ? "border-loss/30"
                : "border-muted/30"
          }`}
        >
          {p.text}
        </span>
      </div>
      <div className="space-y-2 text-sm">
        <div className="flex justify-between">
          <span className="text-secondary">Equity</span>
          <span>{fmtUsd.format(eq)}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-secondary">P&amp;L</span>
          <span className={pnlColor(pnl)}>
            {pnl >= 0 ? "+" : ""}
            {fmtUsd.format(pnl)}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-secondary">Trades</span>
          <span>{trades}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-secondary">Sharpe</span>
          <span className={sharpe > 0.5 ? "text-profit" : sharpe < 0 ? "text-loss" : ""}>
            {fmtNum.format(sharpe)}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-secondary">Max DD</span>
          <span className="text-loss">{fmtNum.format(maxDD)}%</span>
        </div>
        {extra?.map((e) => (
          <div key={e.label} className="flex justify-between">
            <span className="text-secondary">{e.label}</span>
            <span>{e.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Equity Chart (SVG) ─────────────────────────────── */

interface ChartSeries {
  data: number[];
  color: string;
  label: string;
}

function EquityChart({
  portfolio,
  series,
  benchmark,
}: {
  portfolio: number[];
  series: ChartSeries[];
  benchmark: number[];
}) {
  if (portfolio.length < 2) {
    return (
      <div className="border border-subtle p-5 mb-6 h-48 flex items-center justify-center text-muted">
        Waiting for data...
      </div>
    );
  }

  const W = 800;
  const H = 200;
  const PAD = { top: 20, right: 20, bottom: 30, left: 70 };
  const cw = W - PAD.left - PAD.right;
  const ch = H - PAD.top - PAD.bottom;

  // Compute global min/max across portfolio + all active series + benchmark
  const allData = [portfolio, ...series.map((s) => s.data), ...(benchmark.length > 0 ? [benchmark] : [])];
  let globalMin = Infinity;
  let globalMax = -Infinity;
  for (const d of allData) {
    for (const v of d) {
      if (v < globalMin) globalMin = v;
      if (v > globalMax) globalMax = v;
    }
  }
  const mid = (globalMin + globalMax) / 2;
  const minRange = mid * 0.02;
  if (globalMax - globalMin < minRange) {
    globalMin = mid - minRange / 2;
    globalMax = mid + minRange / 2;
  }
  const range = globalMax - globalMin || 1;

  const x = (i: number, len: number) => PAD.left + (i / (len - 1)) * cw;
  const y = (v: number) => PAD.top + ch - ((v - globalMin) / range) * ch;

  const makePoints = (data: number[]) =>
    data.map((v, i) => `${x(i, data.length)},${y(v)}`).join(" ");

  const portfolioPoints = makePoints(portfolio);
  const areaPoints = `${x(0, portfolio.length)},${y(portfolio[0])} ${portfolioPoints} ${x(portfolio.length - 1, portfolio.length)},${PAD.top + ch} ${x(0, portfolio.length)},${PAD.top + ch}`;

  // Y-axis labels
  const yTicks = 4;
  const yLabels = Array.from({ length: yTicks + 1 }, (_, i) => {
    const v = globalMin + (range * i) / yTicks;
    return { v, yPos: y(v) };
  });

  return (
    <div className="border border-subtle p-5 mb-6">
      <div className="flex items-center justify-between mb-3">
        <div className="text-secondary text-xs uppercase tracking-wider">
          Equity Curve
        </div>
        <div className="flex gap-3 text-xs">
          <span className="text-chart">Portfolio</span>
          {benchmark.length > 0 && (
            <span className="text-muted">GOOG B&amp;H</span>
          )}
          {series.map((s) => (
            <span key={s.label} style={{ color: s.color }}>
              {s.label}
            </span>
          ))}
        </div>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-auto">
        <defs>
          <linearGradient id="eqFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#63b3ed" stopOpacity="0.15" />
            <stop offset="100%" stopColor="#63b3ed" stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {/* Grid lines */}
        {yLabels.map((yl) => (
          <line
            key={yl.v}
            x1={PAD.left}
            y1={yl.yPos}
            x2={W - PAD.right}
            y2={yl.yPos}
            stroke="#28324a"
            strokeWidth="0.5"
          />
        ))}
        {/* Y labels */}
        {yLabels.map((yl) => (
          <text
            key={yl.v}
            x={PAD.left - 8}
            y={yl.yPos + 4}
            textAnchor="end"
            fill="#8c96aa"
            fontSize="10"
          >
            {yl.v >= 1000 ? `$${(yl.v / 1000).toFixed(1)}k` : `$${yl.v.toFixed(0)}`}
          </text>
        ))}
        {/* Area fill for portfolio */}
        <polygon points={areaPoints} fill="url(#eqFill)" />
        {/* GOOG benchmark (dashed, behind everything) */}
        {benchmark.length > 0 && (
          <polyline
            points={makePoints(benchmark)}
            fill="none"
            stroke="#505a6e"
            strokeWidth="1.5"
            strokeDasharray="6 3"
            strokeLinejoin="round"
            opacity="0.6"
          />
        )}
        {/* Strategy lines (behind portfolio) */}
        {series.map((s) => (
          <polyline
            key={s.label}
            points={makePoints(s.data)}
            fill="none"
            stroke={s.color}
            strokeWidth="1.5"
            strokeLinejoin="round"
            opacity="0.7"
          />
        ))}
        {/* Portfolio line */}
        <polyline
          points={portfolioPoints}
          fill="none"
          stroke="#63b3ed"
          strokeWidth="2"
          strokeLinejoin="round"
        />
        {/* Current value dot */}
        <circle
          cx={x(portfolio.length - 1, portfolio.length)}
          cy={y(portfolio[portfolio.length - 1])}
          r="3"
          fill="#63b3ed"
        />
      </svg>
    </div>
  );
}

/* ── Event Log ──────────────────────────────────────── */

function formatEvent(ev: LogEvent): { color: string; text: string } {
  const d = ev.details;
  switch (ev.type) {
    case "TRADE": {
      const strat = STRAT_SHORT[d[0]] ?? `S${d[0]}`;
      const action = d[1]; // ENTRY or EXIT
      const val = d[2];
      if (action === "ENTRY") {
        return { color: "text-info", text: `${strat} entered long @ ${val}` };
      }
      return { color: "text-info", text: `${strat} exited @ ${val}` };
    }
    case "PRICE":
      return {
        color: "text-foreground",
        text: d.join("  "),
      };
    case "EQUITY":
      return {
        color: "text-chart",
        text: `Portfolio ${fmtUsd.format(parseFloat(d[0]))}`,
      };
    case "STRAT": {
      const strat = STRAT_SHORT[d[0]] ?? `S${d[0]}`;
      const pos = d[1]?.replace("pos=", "");
      const eq = d[2]?.replace("eq=", "");
      const posText = pos === "1" ? "LONG" : pos === "-1" ? "SHORT" : "FLAT";
      return {
        color: "text-secondary",
        text: `${strat}: ${posText}, equity ${fmtUsd.format(parseFloat(eq))}`,
      };
    }
    default:
      return { color: "text-muted", text: d.join(" | ") };
  }
}

function EventLog({ events }: { events: LogEvent[] }) {
  const reversed = [...events].slice(-500).reverse();

  // Group by date for tree decoration
  const withTree = reversed.map((ev, i) => {
    const prevDate = i > 0 ? reversed[i - 1].date : null;
    const nextDate = i < reversed.length - 1 ? reversed[i + 1].date : null;
    const isFirst = ev.date !== prevDate;
    const isLast = ev.date !== nextDate;
    let branch: string;
    if (isFirst && isLast) branch = "\u2500\u2500"; // ──  (single item)
    else if (isLast) branch = "\u2514\u2500";       // └─  (last in group)
    else if (isFirst) branch = "\u250C\u2500";       // ┌─  (first in group)
    else branch = "\u251C\u2500";                    // ├─  (middle)
    return { ev, branch, isFirst };
  });

  return (
    <div className="border border-subtle p-5">
      <div className="text-secondary text-xs uppercase tracking-wider mb-3">
        Event Log
      </div>
      <div className="text-xs font-mono max-h-64 overflow-y-auto">
        {withTree.map(({ ev, branch, isFirst }, i) => {
          const fmt = formatEvent(ev);
          return (
            <div key={i} className={`flex gap-2 ${isFirst && i > 0 ? "mt-2" : ""}`}>
              <span className="text-muted shrink-0 w-20">{isFirst ? ev.date : ""}</span>
              <span className="text-muted shrink-0">{branch}</span>
              <span className={`shrink-0 w-14 ${fmt.color}`}>
                {ev.type}
              </span>
              <span className={fmt.color}>{fmt.text}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ── Next Update Countdown ─────────────────────────── */

function NextUpdateCountdown({ seq }: { seq: number }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  // FRED publishes around 10:30 AM ET on weekdays
  const utc = new Date(now);
  const etMins = ((utc.getUTCHours() - 5 + 24) % 24) * 60 + utc.getUTCMinutes();
  const etDay = utc.getUTCDay();
  const isWeekend = etDay === 0 || etDay === 6;
  const targetMins = 10 * 60 + 30; // 10:30 ET

  let label: string;
  if (isWeekend) {
    label = "Markets closed \u00b7 next update Monday";
  } else if (etMins >= targetMins + 30) {
    label = "Next update tomorrow ~10:30 ET";
  } else if (etMins < targetMins) {
    const left = targetMins - etMins;
    const h = Math.floor(left / 60);
    const m = left % 60;
    label = `FRED update in ~${h > 0 ? h + "h " : ""}${m}m`;
  } else {
    label = "Awaiting FRED data\u2026";
  }

  return (
    <div className="text-center text-xs mt-8 pb-4">
      <span className="awaiting-pulse text-muted">{label}</span>
      <span className="text-muted"> &middot; Day {seq}</span>
    </div>
  );
}

/* ── Main Page ──────────────────────────────────────── */

export default function Dashboard() {
  const [data, setData] = useState<AppData | null>(null);
  const [lastCommit, setLastCommit] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [activeStrats, setActiveStrats] = useState<Set<string>>(new Set());

  const toggleStrat = useCallback((id: string) => {
    setActiveStrats((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const loadData = useCallback(async () => {
    try {
      const commit = await fetchCommit();
      if (commit !== lastCommit) {
        const appData = await fetchAppData();
        setData(appData);
        setLastCommit(commit);
        setError(null);
      }
    } catch {
      setError("Failed to fetch data");
    }
  }, [lastCommit]);

  useEffect(() => {
    loadData();
    const id = setInterval(loadData, POLL_INTERVAL);
    return () => clearInterval(id);
  }, [loadData]);

  // Compute per-strategy metrics from equity curves
  const stratMetrics = useMemo(() => {
    if (!data) return null;
    const se = data.stratEquities;
    return {
      s1: { sharpe: computeSharpe(se.s1), maxDD: computeMaxDrawdown(se.s1) },
      s2: { sharpe: computeSharpe(se.s2), maxDD: computeMaxDrawdown(se.s2) },
      s3: { sharpe: computeSharpe(se.s3), maxDD: computeMaxDrawdown(se.s3) },
      s4: { sharpe: computeSharpe(se.s4), maxDD: computeMaxDrawdown(se.s4) },
      s5: { sharpe: computeSharpe(se.s5), maxDD: computeMaxDrawdown(se.s5) },
      s6: { sharpe: computeSharpe(se.s6), maxDD: computeMaxDrawdown(se.s6) },
      portfolio: {
        sharpe: computeSharpe(data.equity),
        maxDD: computeMaxDrawdown(data.equity),
      },
    };
  }, [data]);

  // Build chart series from active strategies
  const chartSeries = useMemo((): ChartSeries[] => {
    if (!data) return [];
    const se = data.stratEquities;
    const map: Record<string, { data: number[]; label: string }> = {
      "1": { data: se.s1, label: "S1" },
      "2": { data: se.s2, label: "S2" },
      "3": { data: se.s3, label: "S3" },
      "4": { data: se.s4, label: "S4" },
      "5": { data: se.s5, label: "S5" },
      "6": { data: se.s6, label: "S6" },
    };
    return Array.from(activeStrats)
      .filter((id) => id in map)
      .map((id) => ({
        data: map[id].data,
        color: STRAT_COLORS[id],
        label: map[id].label,
      }));
  }, [data, activeStrats]);

  if (!data || !stratMetrics) {
    return (
      <div className="min-h-screen flex items-center justify-center text-secondary">
        {error ?? "Loading..."}
      </div>
    );
  }

  const { state, stratOne, stratTwo, stratThree, stratFour, stratFive, stratSix, equity, events } = data;
  const date = `${state.year}-${String(state.month).padStart(2, "0")}-${String(state.day).padStart(2, "0")}`;
  const totalPnl = state.capital - 200_000;

  return (
    <>
      <TradeTicker events={events} />
      <main className="max-w-5xl mx-auto px-4 py-8">
      <Header date={date} seq={state.seq} />
      <BalanceBar capital={state.capital} pnl={totalPnl} />

      {/* Portfolio-level metrics */}
      <div className="font-mono text-sm mb-5 text-secondary leading-relaxed">
        <div>
          <span className="text-muted">&#9500;&#9472;</span>{" "}
          sharpe{" "}
          <span className={stratMetrics.portfolio.sharpe > 0.5 ? "text-profit" : "text-foreground"}>
            {fmtNum.format(stratMetrics.portfolio.sharpe)}
          </span>
        </div>
        <div>
          <span className="text-muted">&#9500;&#9472;</span>{" "}
          max dd{" "}
          <span className="text-loss">
            {fmtNum.format(stratMetrics.portfolio.maxDD)}%
          </span>
        </div>
        <div>
          <span className="text-muted">&#9500;&#9472;</span>{" "}
          trades{" "}
          <span className="text-foreground">
            {(stratOne.trades + stratTwo.trades + stratThree.trades + stratFour.trades + stratFive.trades + stratSix.trades).toLocaleString()}
          </span>
        </div>
        <div>
          <span className="text-muted">&#9492;&#9472;</span>{" "}
          days{" "}
          <span className="text-foreground">
            {state.seq.toLocaleString()}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
        <StratCard
          id="1"
          title="S1: Pelosi Tracker"
          subtitle="NANC > 50d MA"
          pos={stratOne.pos}
          eq={stratOne.eq}
          pnl={stratOne.pnl}
          trades={stratOne.trades}
          sharpe={stratMetrics.s1.sharpe}
          maxDD={stratMetrics.s1.maxDD}
          active={activeStrats.has("1")}
          onClick={() => toggleStrat("1")}
          extra={[
            {
              label: "NANC",
              value: stratOne.nanc
                ? `$${fmtNum.format(stratOne.nanc)}`
                : "--",
            },
          ]}
        />
        <StratCard
          id="2"
          title="S2: NG Seasonal"
          subtitle="Winter long, NG>$3.50, trail"
          pos={stratTwo.pos}
          eq={stratTwo.eq}
          pnl={stratTwo.pnl}
          trades={stratTwo.trades}
          sharpe={stratMetrics.s2.sharpe}
          maxDD={stratMetrics.s2.maxDD}
          active={activeStrats.has("2")}
          onClick={() => toggleStrat("2")}
          extra={[
            { label: "Peak NG", value: `$${fmtNum.format(stratTwo.peakNg)}` },
          ]}
        />
        <StratCard
          id="3"
          title="S3: NQ Trend"
          subtitle="NQ > 200d MA, VIX < 30"
          pos={stratThree.pos}
          eq={stratThree.eq}
          pnl={stratThree.pnl}
          trades={stratThree.trades}
          sharpe={stratMetrics.s3.sharpe}
          maxDD={stratMetrics.s3.maxDD}
          active={activeStrats.has("3")}
          onClick={() => toggleStrat("3")}
        />
        <StratCard
          id="4"
          title="S4: SVXY Vol"
          subtitle="Long SVXY, VIX>mean+RV"
          pos={stratFour.pos}
          eq={stratFour.eq}
          pnl={stratFour.pnl}
          trades={stratFour.trades}
          sharpe={stratMetrics.s4.sharpe}
          maxDD={stratMetrics.s4.maxDD}
          active={activeStrats.has("4")}
          onClick={() => toggleStrat("4")}
          extra={[
            { label: "SVXY", value: `$${fmtNum.format(stratFour.svxy)}` },
          ]}
        />
        <StratCard
          id="5"
          title="S5: LinReg"
          subtitle="NAS100 1-min W=200"
          pos={stratFive.pos}
          eq={stratFive.eq}
          pnl={stratFive.pnl}
          trades={stratFive.trades}
          sharpe={stratMetrics.s5.sharpe}
          maxDD={stratMetrics.s5.maxDD}
          active={activeStrats.has("5")}
          onClick={() => toggleStrat("5")}
        />
        <StratCard
          id="6"
          title="S6: Gold Trend"
          subtitle="Long GLD > 200d MA"
          pos={stratSix.pos}
          eq={stratSix.eq}
          pnl={stratSix.pnl}
          trades={stratSix.trades}
          sharpe={stratMetrics.s6.sharpe}
          maxDD={stratMetrics.s6.maxDD}
          active={activeStrats.has("6")}
          onClick={() => toggleStrat("6")}
          extra={[
            { label: "GLD", value: `$${fmtNum.format(stratSix.gold)}` },
          ]}
        />
      </div>

      <EquityChart portfolio={equity} series={chartSeries} benchmark={data.benchmark} />
      <EventLog events={events} />

      <NextUpdateCountdown seq={state.seq} />
    </main>
    </>
  );
}
