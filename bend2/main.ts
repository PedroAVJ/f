#!/usr/bin/env bun
// Run, this file is the CLI, and the CLI is bare: `bend <words...>` checks
// the file the words name from the folder it runs in (the longest of
// ./a/b.bend and ./a.bend for `bend a b`, or a path to a .bend file) and
// runs its main, the words after it (and any after --) its IO.args. It has
// no commands and no flags; building, verdicts and publishing are the repo's
// internal tool's (tool.ts), which V's build and the gates run. Imported,
// it is the loader that makes `import Game from "./x.bend"` work: a bun
// plugin (preload it in bunfig.toml, list it under [serve.static] plugins,
// or hand it to Bun.build) and a node hook (node --import). A .bend module exports every filled, non-base, non-IO
// def, wrapped so a JS caller passes the live arguments, in one call or
// curried, and gets a plain value back: a constructor is {$: "Name", field:
// value, ...}, a closure is a function, Nat is BigInt, Bool, String and U32
// are native. A page bundles through Bun.build with the loader on, since
// the bun build CLI takes no plugins.

import * as fs from "node:fs";
import * as mod from "node:module";
import * as os from "node:os";
import * as path from "node:path";
import * as url from "node:url";
import * as thr from "node:worker_threads";

import type { BunPlugin } from "bun";

import * as Bend from "./bend.ts";
import * as Comp from "./comp.ts";

// Main
// ====

// Constants
// =========

export const VERSION = "2.0.35";

const USAGE = "bend <words...> runs main in ./<words>.bend (bend " + VERSION + ")";

export const BASE = Bend.BASE_BEND;

export const ORIGIN = process.env.BEND_ORIGIN ?? "https://bend-lang.com";

// the daily version check's cache: when it last asked, and the answer
const CHECK = path.join(os.homedir(), ".bend", "check.json");

const DAY = 86400000;

// the verdict on a book: PASS when every def outside Base is a valid proof
// (see cli_verdict), else FAIL and why
const PASS = "ALL PROOFS CHECK";

const FAIL = "SOME PROOFS FAIL";

const PLUGIN: BunPlugin = {
  name: "bend",
  setup(build) {
    build.onLoad({ filter: /\.bend$/ }, async (args) =>
      ({ contents: await load_js(args.path), loader: "js" }));
  },
};

// CLI
// ===

// cli runs the file the words name, then the daily version check, so the
// check never delays the program's own work. A word with a dash is refused:
// bend has no flags, and a program's own go after --.
async function cli(): Promise<void> {
  const args = process.argv.slice(2);
  const end = args.indexOf("--");
  const words = end < 0 ? args : args.slice(0, end);
  const flag = words.find((a) => a.startsWith("-"));
  if (flag !== undefined) {
    cli_fail(flag + " is not a word: bend has no flags (a program's own go after --)");
  }
  if (words.length === 0) {
    cli_fail("no words: " + USAGE);
  }
  const [file, ...argv] = words[0].endsWith(".bend")
    || fs.statSync(words[0], { throwIfNoEntry: false })?.isFile()
    ? words : path_words(words);
  try {
    process.exitCode = book_run(await book_read(file),
      [file, ...argv, ...end < 0 ? [] : args.slice(end + 1)]);
  } catch (e) {
    cli_say(2, book_err(e) + "\n");
    process.exitCode = 1;
  }
  await check();
}

// check is the whole telemetry: once a day, a GET of /check?v=&os=&arch=
// (nothing else: no id, no command, no timing) whose answer {ver, notice}
// is cached in CHECK; a cached ver newer than this one prints one line on
// stderr, and the notice. The cache is stamped before the request, so a
// day has one request whatever happens to it; BEND_NO_TELEMETRY=1 skips
// everything; the check never fails the command.
async function check(): Promise<void> {
  if (process.env.BEND_NO_TELEMETRY) {
    return;
  }
  let last = { t: 0, ver: VERSION, notice: "" };
  try {
    last = { ...last, ...JSON.parse(fs.readFileSync(CHECK, "utf8")) };
  } catch {}
  try {
    if (Date.now() - last.t > DAY) {
      last.t = Date.now();
      fs.mkdirSync(path.dirname(CHECK), { recursive: true });
      fs.writeFileSync(CHECK, JSON.stringify(last) + "\n");
      const res = await fetch(ORIGIN + "/check?v=" + VERSION + "&os="
        + process.platform + "&arch=" + process.arch,
      { signal: AbortSignal.timeout(3000) });
      const got = await res.json() as { ver?: unknown; notice?: unknown };
      last.ver = typeof got.ver === "string" ? got.ver : VERSION;
      last.notice = typeof got.notice === "string" ? got.notice : "";
      fs.writeFileSync(CHECK, JSON.stringify(last) + "\n");
    }
  } catch {}
  if (ver_newer(last.ver)) {
    cli_say(2, "bend " + last.ver + " is available: curl -fsSL " + ORIGIN
      + "/install.sh | sh\n"
      + (last.notice === "" ? "" : last.notice.replace(/[\x00-\x1f\x7f]/g, "")
      .slice(0, 200) + "\n"));
  }
}

// ua_fetch tags every request to the hub or bend-lang.com with bend/<VERSION>
export function ua_fetch(): void {
  const raw = globalThis.fetch;
  globalThis.fetch = Object.assign((u: string | URL | Request, o: RequestInit = {}) => {
    const to = u instanceof Request ? u.url : String(u);
    return !to.startsWith(Bend.BEND_HUB) && !to.startsWith(ORIGIN) ? raw(u, o)
      : raw(u, { ...o, headers: { ...Object.fromEntries(new Headers(o.headers
        ?? (u instanceof Request ? u.headers : undefined))),
        "user-agent": "bend/" + VERSION } });
  }, raw);
}

function ver_newer(ver: string): boolean {
  const a = ver.split(".").map(Number);
  const b = VERSION.split(".").map(Number);
  return a.length === 3 && a.every(Number.isInteger)
    && (a[0] - b[0] || a[1] - b[1] || a[2] - b[2]) > 0;
}

// path_words resolves `bend a b c`: the longest of a/b/c.bend, a/b.bend and
// a.bend that is a file, then the words after it, its arguments.
function path_words(ws: string[]): string[] {
  const tried = ws.map((_, k) => ws.slice(0, ws.length - k).join("/") + ".bend");
  const k = tried.findIndex((at) => fs.statSync(at, { throwIfNoEntry: false })?.isFile());
  return k >= 0 ? [tried[k], ...ws.slice(ws.length - k)]
    : cli_fail("no file for '" + ws.join(" ") + "': tried " + tried.join(", "));
}

// Verdict
// =======

// cli_verdict prints the verdict on a book bend2 checked: PASS when no
// def outside Base relies on unsafe or foreign code and, given a kernel
// (tool.ts --verdict's BendTT), when it finds nothing wrong; else FAIL and
// why: the kernel's why is a mismatch, bend2 accepted what it rejects.
export function cli_verdict(book: Bend.Book,
  kernel?: (book: Bend.Book) => string | null): number {
  const bad = book_promises(book);
  if (bad.length !== 0) {
    cli_say(2, FAIL + "\nError: " + String(bad.length) + " def" + (bad.length === 1
      ? " relies" : "s rely") + " on unsafe or foreign code:\n"
      + bad.map((k) => "- " + Bend.name_key(k) + "\n").join(""));
    return 1;
  }
  const why = kernel?.(book) ?? null;
  if (why !== null) {
    cli_say(2, FAIL + "\n" + why + "\n");
    return 1;
  }
  cli_say(1, PASS + "\n");
  return 0;
}

// book_promises lists the defs outside Base (laws and types too) that are
// @unsafe or foreign, or whose type, body or constructor fields name a def
// that relies on one: a foreign def is a promise like @unsafe is, as the
// checker reads its type, never its code. If the book holds a promise, a
// walk from the defs outside Base collects who names whom, then the
// promises flood back along those edges.
function book_promises(book: Bend.Book): string[] {
  const own  = [...new Set(book.order)].filter((k) => book.tlds[k].b !== true);
  const bad  = new Set(Object.keys(book.tlds).filter((k) => {
    const t = book.tlds[k] as Bend.Def;
    return t.u === true || (t.i !== undefined && t.b !== true);
  }));
  const uses: Record<string, string[]> = Object.create(null);
  const seen = new Set<string>();
  for (const q = bad.size === 0 ? [] : own.slice(); q.length > 0;) {
    const k = q.pop() as string;
    const t = book.tlds[k];
    if (t !== undefined && !seen.has(k)) {
      seen.add(k);
      const rs = new Set<string>();
      for (const c of t.$ === "ADT" ? t.c : [t]) {
        term_refs(Bend.term_lower(c.T), rs);
      }
      term_refs(t.$ === "Def" ? t.e : undefined, rs);
      for (const r of rs) {
        (uses[r] ??= []).push(k);
        q.push(r);
      }
    }
  }
  for (const k of bad) {
    uses[k]?.forEach((j) => bad.add(j));
  }
  return own.filter((k) => bad.has(k));
}

// term_refs adds to out the names a term (a span skipped) refers to.
function term_refs(tm: unknown, out: Set<string>): void {
  if (typeof tm === "object" && tm !== null) {
    const { $, k } = tm as { $?: string; k?: string };
    if (($ === "Ref" || $ === "ADT") && k !== undefined) {
      out.add(k);
    }
    for (const [f, v] of Object.entries(tm)) {
      if (f !== "s") {
        term_refs(v, out);
      }
    }
  }
}

// cli_say writes text to fd, and drops it if the reader has left (EPIPE).
export function cli_say(fd: number, text: string): void {
  try {
    fs.writeSync(fd, text);
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== "EPIPE") {
      throw e;
    }
  }
}

function cli_fail(msg: string): never {
  cli_say(2, "bend: " + msg + "\n");
  process.exit(1);
}

// Book
// ====

export async function book_read(file: string, base?: Bend.Book,
  seen = new Map<string, string | null>()): Promise<Bend.Book> {
  const book = base === undefined ? Bend.book_nil() : book_seed(base);
  if (base !== undefined) {
    seen.set(BASE, "");
  }
  try {
    await Bend.book_load(book, file, "", seen);
    const laws = path.join(path.dirname(file), "LAWS.bend");
    if (path.basename(file) === "PROOF.bend" && fs.existsSync(laws)
      && !seen.has(fs.realpathSync(laws))) {
      throw "Error: PROOF.bend must import ./LAWS.bend";
    }
    Bend.book_valid(book, base?.order.length ?? 0);
    if (book.hols > 0) {
      throw "Error: " + String(book.hols) + " TODO" + (book.hols === 1 ? "" : "s")
        + " found.\nThe code is incomplete, and not a valid proof yet.";
    }
  } catch (e) {
    throw new Check_Fail(e);
  }
  return book;
}

// a failed check: bend2's reason, which book_err prints under FAIL
class Check_Fail {
  constructor(readonly why: unknown) {}
}

function book_seed(base: Bend.Book): Bend.Book {
  const book = Bend.book_nil();
  for (const k of Object.keys(base.tlds)) {
    book.tlds[k] = { ...base.tlds[k] };
  }
  Object.assign(book.ctrs, base.ctrs);
  for (const k of Object.keys(base.tmps)) {
    book.tmps[k] = new Map(base.tmps[k]);
  }
  book.order.push(...base.order);
  return book;
}

function book_main(book: Bend.Book): Bend.Def | null {
  const main = book.tlds["main"];
  return main === undefined || main.$ !== "Def"
    || (main.v === null && main.i === undefined) ? null : main;
}

export function book_run(book: Bend.Book, argv: string[]): number {
  const main = book_main(book);
  if (main === null) {
    return cli_verdict(book);
  }
  if (Comp.io_type(book) !== null) {
    return Comp.io_run(book, argv);
  }
  const snf = Bend.term_snf(book, main.v as Bend.HTerm);
  cli_say(1, Bend.term_show(Bend.term_lower(snf)) + "\n");
  return 0;
}

export function book_err(e: unknown): string {
  if (e instanceof Check_Fail) {
    return FAIL + "\n" + book_err(e.why);
  }
  const err = e as Bend.Err;
  if (e instanceof RangeError) {
    return "Error: the machine stack overflowed (a deep recursion, or a"
      + " literal too large to expand)";
  }
  return err?.$ === "Err" ? Bend.err_show(err) : String(e);
}

// Load
// ====

async function load_js(path: string): Promise<string> {
  try {
    return Comp.js_lib(await book_read(path), true);
  } catch (e) {
    throw new Error(book_err(e));
  }
}

export async function load(u: string, context: unknown,
  next: (u: string, context: unknown) => unknown): Promise<unknown> {
  return u.endsWith(".bend")
    ? { format: "module", shortCircuit: true,
      source: await load_js(url.fileURLToPath(u)) }
    : next(u, context);
}

export default PLUGIN;

if (import.meta.main) {
  if (typeof Bun === "undefined") {
    cli_say(2, "bend runs on Bun: curl -fsSL https://bend-lang.com/install.sh"
      + " | sh\n");
    process.exit(1);
  }
  ua_fetch();
  await cli();
  process.exit();
} else if (typeof Bun !== "undefined") {
  Bun.plugin(PLUGIN);
} else if (thr.isMainThread || thr.isInternalThread === false) {
  mod.register(import.meta.url);
}
