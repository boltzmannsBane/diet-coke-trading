import type {
  AppData,
  GlobalState,
  StratOne,
  StratTwo,
  StratThree,
  StratFour,
  StratFive,
  StratSix,
  StratEquities,
  LogEvent,
} from "./types";

const BASE = "/data/live";

function parseState(arr: number[]): GlobalState {
  return {
    capital: arr[0],
    seq: arr[1],
    year: arr[2],
    month: arr[3],
    day: arr[4],
  };
}

function parseStratOne(arr: number[]): StratOne {
  return {
    pos: arr[0],
    alloc: arr[1],
    pnl: arr[2],
    nanc: arr[3],
    trades: arr[4],
    eq: arr[5],
  };
}

function parseStratTwo(arr: number[]): StratTwo {
  return {
    pos: arr[0],
    peakNg: arr[1],
    alloc: arr[2],
    pnl: arr[3],
    ng: arr[4],
    trades: arr[5],
    eq: arr[6],
    stopped: arr[7],
  };
}

function parseStratThree(arr: number[]): StratThree {
  return {
    pos: arr[0],
    alloc: arr[1],
    pnl: arr[2],
    nq: arr[3],
    trades: arr[4],
    eq: arr[5],
  };
}

function parseStratFour(arr: number[]): StratFour {
  return {
    pos: arr[0],
    alloc: arr[1],
    pnl: arr[2],
    svxy: arr[3],
    trades: arr[4],
    eq: arr[5],
  };
}

function parseStratFive(arr: number[]): StratFive {
  return {
    pos: arr[0],
    alloc: arr[1],
    pnl: arr[2],
    nq: arr[3],
    trades: arr[4],
    eq: arr[5],
  };
}

function parseStratSix(arr: number[]): StratSix {
  return {
    pos: arr[0],
    alloc: arr[1],
    pnl: arr[2],
    gold: arr[3],
    trades: arr[4],
    eq: arr[5],
  };
}

function parseEvents(text: string): LogEvent[] {
  return text
    .trim()
    .split("\n")
    .filter((line) => line.length > 0)
    .map((line) => {
      const parts = line.split("|");
      return {
        seq: parseInt(parts[0]),
        date: parts[1],
        type: parts[2],
        details: parts.slice(3),
      };
    });
}

export async function fetchCommit(): Promise<number> {
  const res = await fetch(`${BASE}/commit`, { cache: "no-store" });
  return parseInt((await res.text()).trim());
}

export async function fetchAppData(): Promise<AppData> {
  const [stateRes, s1Res, s2Res, s3Res, s4Res, s5Res, s6Res, eqRes, seqRes, evRes, bmRes, commit] =
    await Promise.all([
      fetch(`${BASE}/state.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_one.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_two.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_three.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_four.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_five.json`, { cache: "no-store" }),
      fetch(`${BASE}/strat_six.json`, { cache: "no-store" }),
      fetch(`${BASE}/equity.json`, { cache: "no-store" }),
      fetch(`${BASE}/equity_strats.json`, { cache: "no-store" }),
      fetch(`${BASE}/events.log`, { cache: "no-store" }),
      fetch(`${BASE}/benchmark.json`, { cache: "no-store" }).catch(() => null),
      fetchCommit(),
    ]);

  const [stateArr, s1Arr, s2Arr, s3Arr, s4Arr, s5Arr, s6Arr, eqArr, seqArr, evText] = await Promise.all([
    stateRes.json(),
    s1Res.json(),
    s2Res.json(),
    s3Res.json(),
    s4Res.json(),
    s5Res.json(),
    s6Res.json(),
    eqRes.json(),
    seqRes.json(),
    evRes.text(),
  ]);
  const bmArr: number[] = bmRes ? await bmRes.json() : [];

  return {
    state: parseState(stateArr),
    stratOne: parseStratOne(s1Arr),
    stratTwo: parseStratTwo(s2Arr),
    stratThree: parseStratThree(s3Arr),
    stratFour: parseStratFour(s4Arr),
    stratFive: parseStratFive(s5Arr),
    stratSix: parseStratSix(s6Arr),
    equity: eqArr,
    stratEquities: seqArr as StratEquities,
    events: parseEvents(evText),
    benchmark: bmArr,
    commit: commit,
  };
}
