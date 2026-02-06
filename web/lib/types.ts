export interface GlobalState {
  capital: number;
  seq: number;
  year: number;
  month: number;
  day: number;
}

export interface StratOne {
  pos: number;
  alloc: number;
  pnl: number;
  nanc: number;
  trades: number;
  eq: number;
}

export interface StratTwo {
  pos: number;
  peakNg: number;
  alloc: number;
  pnl: number;
  ng: number;
  trades: number;
  eq: number;
  stopped: number;
}

export interface StratThree {
  pos: number;
  alloc: number;
  pnl: number;
  nq: number;
  trades: number;
  eq: number;
}

export interface StratFour {
  pos: number;
  alloc: number;
  pnl: number;
  svxy: number;
  trades: number;
  eq: number;
}

export interface StratFive {
  pos: number;
  alloc: number;
  pnl: number;
  nq: number;
  trades: number;
  eq: number;
}

export interface StratSix {
  pos: number;
  alloc: number;
  pnl: number;
  gold: number;
  trades: number;
  eq: number;
}

export interface LogEvent {
  seq: number;
  date: string;
  type: string;
  details: string[];
}

export interface StratEquities {
  s1: number[];
  s2: number[];
  s3: number[];
  s4: number[];
  s5: number[];
  s6: number[];
}

export interface AppData {
  state: GlobalState;
  stratOne: StratOne;
  stratTwo: StratTwo;
  stratThree: StratThree;
  stratFour: StratFour;
  stratFive: StratFive;
  stratSix: StratSix;
  equity: number[];
  stratEquities: StratEquities;
  events: LogEvent[];
  benchmark: number[];
  commit: number;
}
