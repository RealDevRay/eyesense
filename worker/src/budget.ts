/**
 * Durable budget accounting.
 *
 * The daily ceiling is global. The per-minute ceiling is per client IP.
 * A Durable Object is the production store so separate isolates share one
 * counter. Tests use the in-process store, which still reserves atomically.
 */

export const MAX_CONCURRENT = 10;
export const MAX_PER_MINUTE = 30;
export const MAX_DAILY = 1000;
export const MAX_PREPARSE_PER_MINUTE = 60;

export interface WindowCount {
  count: number;
  windowStart: number;
}

export interface BudgetSnapshot {
  concurrent: number;
  dailyCount: number;
  dailyKey: string;
  minutes: Record<string, WindowCount>;
  preparse: Record<string, WindowCount>;
}

export interface BudgetDecision {
  allowed: boolean;
  code?: string;
  message?: string;
  retryAfter?: number;
  charged?: boolean;
}

export function emptyBudget(now = Date.now()): BudgetSnapshot {
  return {
    concurrent: 0,
    dailyCount: 0,
    dailyKey: utcDayKey(now),
    minutes: {},
    preparse: {},
  };
}

export function utcDayKey(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

export function secondsUntilUtcMidnight(now: number): number {
  const date = new Date(now);
  const next = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1);
  return Math.max(1, Math.ceil((next - now) / 1000));
}

function rollDay(state: BudgetSnapshot, now: number): BudgetSnapshot {
  const key = utcDayKey(now);
  if (state.dailyKey === key) return state;
  return {
    concurrent: state.concurrent,
    dailyCount: 0,
    dailyKey: key,
    minutes: {},
    preparse: {},
  };
}

function bumpWindow(existing: WindowCount | undefined, now: number): WindowCount {
  if (!existing || now - existing.windowStart > 60_000) {
    return { count: 1, windowStart: now };
  }
  return { count: existing.count + 1, windowStart: existing.windowStart };
}

export function previewPreparse(state: BudgetSnapshot, client: string, now: number): {
  state: BudgetSnapshot;
  decision: BudgetDecision;
} {
  const current = rollDay(state, now);
  const window = current.preparse[client];
  if (window && now - window.windowStart <= 60_000 && window.count >= MAX_PREPARSE_PER_MINUTE) {
    const retryAfter = Math.max(1, Math.ceil((window.windowStart + 60_000 - now) / 1000));
    return {
      state: current,
      decision: {
        allowed: false,
        code: "RATE_LIMITED",
        message: "Too many requests. Please wait before retrying.",
        retryAfter,
      },
    };
  }
  return {
    state: {
      ...current,
      preparse: { ...current.preparse, [client]: bumpWindow(window, now) },
    },
    decision: { allowed: true },
  };
}

export function previewCharge(state: BudgetSnapshot, client: string, now: number): {
  state: BudgetSnapshot;
  decision: BudgetDecision;
} {
  const current = rollDay(state, now);
  if (current.dailyCount >= MAX_DAILY) {
    return {
      state: current,
      decision: {
        allowed: false,
        code: "DAILY_BUDGET_EXHAUSTED",
        message: "Daily hosted usage allowance reached. Please use local Read Text or retry tomorrow.",
        retryAfter: secondsUntilUtcMidnight(now),
      },
    };
  }
  if (current.concurrent >= MAX_CONCURRENT) {
    return {
      state: current,
      decision: {
        allowed: false,
        code: "CONCURRENCY_LIMIT_REACHED",
        message: "Too many concurrent requests. Please wait a moment and retry.",
        retryAfter: 3,
      },
    };
  }
  const minute = current.minutes[client];
  if (minute && now - minute.windowStart <= 60_000 && minute.count >= MAX_PER_MINUTE) {
    const retryAfter = Math.max(1, Math.ceil((minute.windowStart + 60_000 - now) / 1000));
    return {
      state: current,
      decision: {
        allowed: false,
        code: "RATE_LIMITED",
        message: "Client rate limit reached. Please wait before retrying.",
        retryAfter,
      },
    };
  }
  return {
    state: {
      ...current,
      concurrent: current.concurrent + 1,
      dailyCount: current.dailyCount + 1,
      minutes: { ...current.minutes, [client]: bumpWindow(minute, now) },
    },
    decision: { allowed: true, charged: true },
  };
}

export function releaseConcurrent(state: BudgetSnapshot): BudgetSnapshot {
  return { ...state, concurrent: Math.max(0, state.concurrent - 1) };
}

export class BudgetStore {
  snapshot: BudgetSnapshot;

  constructor(snapshot?: BudgetSnapshot) {
    this.snapshot = snapshot ?? emptyBudget();
  }

  preparse(client: string, now = Date.now()): BudgetDecision {
    const next = previewPreparse(this.snapshot, client, now);
    this.snapshot = next.state;
    return next.decision;
  }

  charge(client: string, now = Date.now()): BudgetDecision {
    const next = previewCharge(this.snapshot, client, now);
    this.snapshot = next.state;
    return next.decision;
  }

  release(): void {
    this.snapshot = releaseConcurrent(this.snapshot);
  }
}

export const memoryBudget = new BudgetStore();

let memoryChain: Promise<void> = Promise.resolve();

export function memoryExclusive<T>(fn: () => T): Promise<T> {
  const run = memoryChain.then(fn, fn);
  memoryChain = run.then(
    () => undefined,
    () => undefined,
  );
  return run;
}

export function resetMemoryBudget(now = Date.now()): void {
  memoryBudget.snapshot = emptyBudget(now);
}

interface DurableBinding {
  idFromName(name: string): unknown;
  get(id: unknown): { fetch(input: RequestInfo, init?: RequestInit): Promise<Response> };
}

export async function preparseClient(binding: DurableBinding | undefined, client: string, now = Date.now()): Promise<BudgetDecision> {
  if (!binding) return memoryExclusive(() => memoryBudget.preparse(client, now));
  return callDurable(binding, { op: "preparse", client, now });
}

export async function chargeClient(binding: DurableBinding | undefined, client: string, now = Date.now()): Promise<BudgetDecision> {
  if (!binding) return memoryExclusive(() => memoryBudget.charge(client, now));
  return callDurable(binding, { op: "charge", client, now });
}

export async function releaseClient(binding: DurableBinding | undefined): Promise<void> {
  if (!binding) {
    await memoryExclusive(() => memoryBudget.release());
    return;
  }
  await callDurable(binding, { op: "release", client: "", now: Date.now() });
}

async function callDurable(binding: DurableBinding, body: { op: string; client: string; now: number }): Promise<BudgetDecision> {
  const stub = binding.get(binding.idFromName("global"));
  const response = await stub.fetch("https://budget.internal/", {
    method: "POST",
    body: JSON.stringify(body),
  });
  return (await response.json()) as BudgetDecision;
}

export class BudgetDurableObject {
  private store: BudgetStore | null = null;

  constructor(private readonly state: { storage: { get<T>(key: string): Promise<T | undefined>; put(key: string, value: unknown): Promise<void> } }) {}

  async fetch(request: Request): Promise<Response> {
    const body = (await request.json()) as { op: string; client: string; now: number };
    if (!this.store) {
      const stored = await this.state.storage.get<BudgetSnapshot>("budget");
      this.store = new BudgetStore(stored ?? emptyBudget(body.now));
    }
    let decision: BudgetDecision = { allowed: true };
    if (body.op === "preparse") decision = this.store.preparse(body.client, body.now);
    else if (body.op === "charge") decision = this.store.charge(body.client, body.now);
    else if (body.op === "release") this.store.release();
    await this.state.storage.put("budget", this.store.snapshot);
    return new Response(JSON.stringify(decision), { headers: { "Content-Type": "application/json" } });
  }
}
