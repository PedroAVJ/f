#!/usr/bin/env bun
// The repo's internal tool: what the gates, V's build, gen_pins.ts and the
// hub release path run. It is not the user's CLI (that is main.ts: `bend
// <words...>` runs a main, and nothing else) and it is not documented for
// users. It reads its file through main.ts's loader and Base.
//
//   bun bend2/tool.ts <file.bend> -o <out>...      build: a binary, or C, JS,
//                                                   .mjs, .web or BendTT by extension
//   bun bend2/tool.ts <file.bend> -o <dir>.macos --id <bundle id> --name <name>
//     [--version N] [--short X.Y] [--origin <url>] [--identity <sha1|name|->]
//                                                   a Mac app (see Mac below)
//   bun bend2/tool.ts <page.html> -o <dir>          bundle a page that imports .bend
//   bun bend2/tool.ts <file.bend> --check-only      check it and its imports
//   bun bend2/tool.ts <file.bend> --verdict         then recheck with BendTT's kernel
//   bun bend2/tool.ts <file.bend> --checkup         check and run each import alone
//   bun bend2/tool.ts <file.bend> --publish [<name>@<version>]
//   bun bend2/tool.ts link <name>@<version> 0x<hash>
//   bun bend2/tool.ts login
//   bun bend2/tool.ts base [--types|<name>]
//
// $BEND_NO_BASE (the gates' base-less tests) and $BEND_EMCC (the .web
// build's emcc) are its switches; a built binary keeps its own runtime
// options (--threads, --gpu, --gpu-build, --bend-help).

import * as child from "node:child_process";
import * as crypto from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as thr from "node:worker_threads";

import * as Bend from "./bend.ts";
import * as Comp from "./comp.ts";
import * as Main from "./main.ts";
import * as Safe from "./safe.ts";

// Constants
// =========

const say = Main.cli_say;

// the Bender key `tool.ts login` wrote: {key, login}, mode 0600
const BENDER = path.join(os.homedir(), ".bend", "bender.json");

const MISMATCH = "Sorry - this is a mismatch between the TypeScript implementation,"
  + " and the formalized BendTT kernel. Your proofs may or may not be correct, and"
  + " we cannot validate them yet. This will be addressed in a future update."
  + " Meanwhile, feel free to open an issue to report this bug.";

// BendHub's terms; s18.4 makes MIT-0 the default license
const TERMS = "https://bend-lang.com/bender/terms#s18";

// the hub's SPDX line rule (hubdb.ts)
const SPDX_RE = /^\s*SPDX-License-Identifier:\s*([A-Za-z0-9.+\-() ]{1,80}?)\s*$/;

// A package's proof of work is a nonce whose sha256(hash + " " + nonce)
// opens (its top 53 bits) with a number under 2^53 / work, where work is
// the hub's pow hashes (GET /pow.json; two seconds of an M4 Max's sixteen
// cores) per 256 KiB of package, and no less. Every core mines; the hub
// checks it with one hash.
const POW_JS = `
const crypto = require("node:crypto");
const { parentPort, workerData: { pre, lim, from, step } }
  = require("node:worker_threads");
for (let n = from;; n += step) {
  const h = crypto.hash("sha256", pre + n, "buffer");
  if ((h[0] * 16777216 + (h[1] << 16) + (h[2] << 8) + h[3]) * 2097152
    + ((h[4] * 16777216 + (h[5] << 16) + (h[6] << 8) + h[7]) >>> 11) < lim) {
    parentPort.postMessage(n);
    break;
  }
}`;

// Tool
// ====

function fail(msg: string): never {
  say(2, "bend2/tool.ts: " + msg + "\n");
  process.exit(1);
}

async function tool(): Promise<void> {
  const args = process.argv.slice(2);
  if (args[0] === "login" || args[0] === "link") {
    if (args.length !== (args[0] === "link" ? 3 : 1)) {
      fail(args[0] === "link" ? "link takes <name>@<version> and 0x<hash>"
        : args[0] + " takes no argument");
    }
    try {
      await (args[0] === "login" ? login() : link(args[1], args[2]));
    } catch (e) {
      say(2, Main.book_err(e) + "\n");
      process.exitCode = 1;
    }
    return;
  }
  if (args[0] === "base" && args.length <= 2) {
    return base(args[1]);
  }
  const outs: string[] = [];
  const mac: Record<string, string> = {};
  let file: string | undefined;
  let only = false;
  let verdict = false;
  let checkup = false;
  let publish = false;
  let named: string | undefined;
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (MAC_FLAGS.includes(a)) {
      i += 1;
      mac[a.slice(2)] = args[i] ?? fail(a + " needs a value");
    } else if (a === "--check-only") {
      only = true;
    } else if (a === "--verdict") {
      verdict = true;
    } else if (a === "--checkup") {
      checkup = true;
    } else if (a === "--publish") {
      publish = true;
      if (args[i + 1]?.includes("@")) {
        i += 1;
        named = args[i];
        named_parts(named);
      }
    } else if (a === "-o") {
      i += 1;
      outs.push(args[i] ?? fail("-o needs an output file"));
    } else if (a.startsWith("-") || file !== undefined) {
      fail("unknown argument " + a);
    } else {
      file = a;
    }
  }
  const asks = Number(only) + Number(verdict) + Number(checkup) + Number(publish)
    + Number(outs.length !== 0);
  if (file === undefined || asks === 0) {
    fail("give a file and one of -o <out>, --check-only, --verdict, --checkup, --publish");
  }
  if (asks !== 1) {
    fail((publish ? "--publish" : outs.length !== 0 ? "-o" : "--verdict")
      + " takes no other option");
  }
  if (Object.keys(mac).length !== 0 && !outs.some((o) => o.endsWith(".macos"))) {
    fail(MAC_FLAGS.join(", ") + " go with -o <dir>.macos");
  }
  if (file.endsWith(".html")) {
    return outs.length === 1 ? bundle(file, outs[0]) : fail("a page bundles with -o <dir>");
  }
  try {
    if (publish) {
      return await pkg_publish(file, named);
    }
    if (checkup) {
      return await checkup_run(file);
    }
    const seen = new Map<string, string | null>();
    const book = await Main.book_read(file, undefined, seen);
    if (only || verdict) {
      process.exitCode = Main.cli_verdict(book, verdict
        ? (b) => Safe.safe_check(b) ? null : MISMATCH : undefined);
      return;
    }
    const ins = new Set([...seen.keys(), ...Object.values(book.tlds).flatMap((t) =>
      t.$ === "Def" && t.i !== undefined ? t.i.map(path_real) : [])]);
    for (const out of outs) {
      const at = path_real(out);
      if (ins.has(at) || (fs.existsSync(at) && fs.statSync(at).isDirectory() && !/\.(web|macos)$/.test(out))) {
        fail("-o " + out + " is a file the program reads, or a directory");
      }
      emit(book, out, mac);
    }
  } catch (e) {
    say(2, Main.book_err(e) + "\n");
    process.exitCode = 1;
  }
}

// checkup_run checks and runs each import of the file alone (Base read
// once, seeded into every module; none under $BEND_NO_BASE, the gates'
// base-less tests); one that fails fails it.
async function checkup_run(file: string): Promise<void> {
  const base = process.env.BEND_NO_BASE ? undefined : await Main.book_read(Main.BASE);
  let bad = false;
  for (const raw of fs.readFileSync(file, "utf8").split("\n")) {
    const m = /^import\s+(\S+)\s+as\s+[A-Za-z_][A-Za-z0-9_]*\s*$/
      .exec(raw.trim());
    if (m === null) {
      continue;
    }
    const at = m[1].startsWith("/") ? m[1]
      : path.join(path.dirname(file), m[1]);
    say(1, "--- " + m[1] + " ---\n");
    let code = 1;
    try {
      code = Main.book_run(await Main.book_read(at, base), [at]);
    } catch (e) {
      say(2, Main.book_err(e) + "\n");
    }
    if (code !== 0) {
      say(1, "exit " + String(code) + "\n");
      bad = true;
    }
  }
  if (bad) {
    process.exit(1);
  }
}

function path_real(p: string): string {
  return fs.existsSync(p) ? fs.realpathSync(p) : path.resolve(p);
}

// Build
// =====

function emit(book: Bend.Book, out: string, mac: Record<string, string> = {}): void {
  if (out.endsWith(".macos")) {
    mac_build(book, out, mac_opts(mac));
  } else if (out.endsWith(".web")) {
    const dir = fs.mkdtempSync(path.join(path.dirname(path.resolve(out)), ".bend-web-"));
    try {
      const c = path.join(dir, "app.c");
      fs.writeFileSync(c, Comp.compile_book(book, true));
      const flags = [c, "-O3", "-DBEND_WEB=1", "--js-library",
        path.join(Bend.BEND_DIR, "std/F/browser/stdio.js"), "-sMODULARIZE=1", "-sEXPORT_ES6=1",
        "-sENVIRONMENT=web,worker,node", "-sINVOKE_RUN=0", "-sASYNCIFY=1",
        "-sASYNCIFY_STACK_SIZE=262144", "-sINITIAL_MEMORY=134217728",
        "-sALLOW_MEMORY_GROWTH=0", "-sSTACK_SIZE=1048576",
        "-sEXPORTED_FUNCTIONS=_bend_start,_bend_worker_rows,_malloc,_free",
        "-sEXPORTED_RUNTIME_METHODS=ccall"];
      for (const threaded of [false, true]) {
        const args = [...flags, ...(threaded ? ["-pthread", "-sEXPORTED_RUNTIME_METHODS=ccall,PThread", "-sPTHREAD_POOL_SIZE=8",
          "-sDEFAULT_PTHREAD_STACK_SIZE=1048576"] : []), "-o",
          path.join(dir, threaded ? "threads.mjs" : "seq.mjs")];
        const got = child.spawnSync(process.env.BEND_EMCC ?? "emcc", args, {stdio:"inherit"});
        if (got.status !== 0) throw "Error: web build needs Emscripten (emcc or BEND_EMCC)";
      }
      for (const name of ["worker.js", "shell.js", "gpu.js", "renderer.js"]) {
        fs.copyFileSync(path.join(Bend.BEND_DIR, "std/F/browser", name), path.join(dir, name));
      }
      fs.writeFileSync(path.join(dir, "index.html"), `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bend</title>
<div id="app"></div><pre id="output"></pre><script type="module">
import {startBend} from './shell.js';
window.bend = startBend(document.getElementById('app'), {workers:Number(new URLSearchParams(location.search).get('workers')) || undefined,
onMessage:m => { if (m.type === 'stdout' || m.type === 'stderr' || m.type === 'error') document.getElementById('output').textContent = (document.getElementById('output').textContent + (m.text || '') + '\\n').slice(-65536); }});
</script>`);
      const files = [...fs.readdirSync(dir).filter(n => n !== "app.c"), "manifest.json"];
      fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify({bendWeb:1, files, memoryBytes:134217728,
        corpusBytes:33554432, workStackBytes:2097152, maxWorkers:8,
        headers:{"Cross-Origin-Opener-Policy":"same-origin", "Cross-Origin-Embedder-Policy":"require-corp"}}, null, 2));
      fs.unlinkSync(c);
      if (fs.existsSync(out)) {
        const manifest = path.join(out, "manifest.json");
        if (!fs.existsSync(manifest) || JSON.parse(fs.readFileSync(manifest,"utf8")).bendWeb !== 1) {
          throw "Error: refusing to replace a directory without a Bend web manifest";
        }
        // Keep caller-owned assets while replacing generated build files.
        const old = JSON.parse(fs.readFileSync(manifest,"utf8"));
        const owned = new Set(old.files ?? ["index.html", "manifest.json", "seq.mjs", "seq.wasm",
          "threads.mjs", "threads.wasm", "worker.js", "shell.js"]);
        for (const name of fs.readdirSync(out)) {
          if (!owned.has(name) && !fs.existsSync(path.join(dir,name))) {
            fs.cpSync(path.join(out,name), path.join(dir,name), {recursive:true,verbatimSymlinks:true});
          }
        }
        const previous = out + ".previous-" + crypto.randomBytes(6).toString("hex");
        fs.renameSync(out, previous);
        try { fs.renameSync(dir, out); }
        catch (e) { fs.renameSync(previous, out); throw e; }
        fs.rmSync(previous, {recursive:true});
      } else {
        fs.renameSync(dir, out);
      }
    } finally { fs.rmSync(dir, {recursive:true,force:true}); }
  } else if (out.endsWith(".mjs")) {
    fs.writeFileSync(out, Comp.js_lib(book, true));
  } else if (/\.c?js$/.test(out)) {
    fs.writeFileSync(out, Comp.js_book(book));
  } else if (out.endsWith(".c")) {
    fs.writeFileSync(out, Comp.compile_book(book));
  } else if (out.endsWith(".bendtt")) {
    const oos = Safe.safe_emit(book, out);
    if (oos.length !== 0) {
      say(2, "BendTT: out of scope, so not in " + out + ":\n" + oos.join(""));
    }
  } else {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bend-"));
    const c   = path.join(dir, path.basename(out) + ".c");
    fs.writeFileSync(c, Comp.compile_book(book));
    try {
      build(out, c);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
}

// cc_find is the first of $CC, clang and every clang-NN on PATH (newest
// first) that is new enough: clang 14 for a CPU build, and for a GPU build
// clang 19 (Apple clang 17, which ships LLVM 19), whose #embed
// carries the device program.
function cc_find(gpu: boolean): string {
  function dir_list(dir: string): string[] {
    try {
      return fs.readdirSync(dir);
    } catch {
      return [];
    }
  }
  const dirs = (process.env.PATH ?? "").split(path.delimiter);
  const nums = [...new Set(dirs.flatMap(dir_list).filter((f) =>
    /^clang-\d+$/.test(f)))].sort((a, b) => Number(b.slice(6)) - Number(a.slice(6)));
  const olds: string[] = [];
  const ccs  = [...(process.env.CC ? [process.env.CC] : []), "clang", ...nums];
  for (const cc of ccs) {
    const [got, out] = Safe.run_read(cc, ["--version"]);
    const m   = /^(Apple )?(?:\w+ )?clang version (\d+)/m.exec(out);
    const need = gpu ? (m?.[1] === undefined ? 19 : 17) : 14;
    if (m !== null && Number(m[2]) >= need) {
      return cc;
    }
    olds.push(m !== null ? "clang " + m[2] + " as " + cc
      : got.status === 0 && out ? cc + ", which is not clang" : "no " + cc);
  }
  throw "Error: bend needs clang " + (gpu ? "19 (Apple clang 17)" : "14")
    + " or newer to build " + (gpu ? "a GPU program" : "binaries") + " (found "
    + olds.join(", ") + "); on Debian/Ubuntu: curl -fsSL"
    + " https://apt.llvm.org/llvm.sh | sudo bash -s 19; on macOS: xcode-select"
    + " --install";
}

// build builds the C file at `file` into the binary `bin`. A `!` program
// builds with the GPU lane and writes its GPU program too (on Linux only with
// CUDA at $CUDA_HOME, else at /usr/local/cuda, its libraries in lib64 or, as
// nix lays them, lib; else the ! runs on the cores). On macOS a program with
// a framework (#import: a window, audio) builds as Objective-C; on Linux it
// links the X11 and ALSA libraries it includes.
function build(bin: string, file: string): void {
  const c     = fs.readFileSync(file, "utf8");
  const mac   = process.platform === "darwin";
  const cuda  = process.env.CUDA_HOME || "/usr/local/cuda";
  const bangs = !/^#define BANGS\s+0$/m.test(c)
    && (mac || fs.existsSync(cuda + "/include/nvrtc.h"));
  const cc    = cc_find(bangs);
  const objc  = mac && (bangs || /^#import /m.test(c))
    ? ["-x", "objective-c", "-fobjc-arc", "-fmodules"] : [];
  const libs  = [["X11", "X11"], ["alsa", "asound"]].flatMap(([h, l]) =>
    !mac && c.includes("#include <" + h + "/") ? ["-l" + l] : []);
  const cpu = [...objc, "-std=c11", "-O3", file, "-lpthread", "-lm",
    ...libs, "-o", path.resolve(bin)];
  const gpu = mac ? ["-DBEND_METAL=1", ...cpu]
    : ["-DBEND_CUDA=1", "-I" + cuda + "/include", "-L" + cuda + "/lib64",
      "-L" + cuda + "/lib", ...cpu, "-lcuda", "-lnvrtc"];
  const steps: [string, string[]][] = bangs
    ? [[cc, gpu], [path.resolve(bin), ["--gpu-build"]]] : [[cc, cpu]];
  for (const [cmd, args] of steps) {
    if (child.spawnSync(cmd, args, { stdio: "inherit" }).status !== 0) {
      throw "Error: " + path.basename(cmd) + " failed to build " + bin;
    }
  }
}

async function bundle(page: string, dir: string): Promise<void> {
  const out = await Bun.build({
    entrypoints: [page],
    outdir: dir,
    target: "browser",
    minify: true,
    plugins: [Main.default],
  });
  for (const a of out.outputs) {
    say(1, a.path + " (" + (a.size / 1024).toFixed(1) + "kb)\n");
  }
}

// Mac
// ===

// -o <dir>.macos builds a Bend program as a Mac app, <dir>/<name>.app, with
// no Xcode project and no Swift. The program's C, built with
// -DBEND_NATIVE=1 (std/F/browser/host.c's requests then go to the shell)
// and its main renamed bend_main, links with std/F/apple/shell.c (the
// app's main: AppKit owns the main thread, Bend runs on its own, and the
// shell answers the browser's requests: events, canvas paints, fetch and
// post) and std/F/apple/paint.c (the canvas painter: renderer.js in
// CoreGraphics), both Objective-C in .c files, as effs/window.c is. The
// bundle gets a generated Info.plist (CFBundleVersion --version, the build's
// Unix time by default; BendOrigin --origin, the base of relative fetch
// URLs) and is signed with --identity, else the keychain's first Apple
// Development identity, else ad hoc (-), which it also falls back to when
// that identity cannot sign (a locked keychain). <dir>/manifest.json
// records the build; a build replaces only a directory that has one.

const MAC_FLAGS = ["--id", "--name", "--version", "--short", "--origin", "--identity"];

const MAC_MIN = "14.0";

type MacOpts = {
  id: string; name: string; version: string; short: string; origin?: string;
  identity?: string;
};

function mac_opts(o: Record<string, string>): MacOpts {
  const id = o.id ?? fail("-o <dir>.macos needs --id <bundle id>, like com.you.app");
  const name = o.name ?? fail("-o <dir>.macos needs --name <the app's name>");
  if (!/^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/.test(id)) {
    fail("--id " + id + " is not a bundle id (letters, digits, - and dots, like com.you.app)");
  }
  if (name.trim() !== name || name === "" || name.startsWith(".") || /[/:\0-\x1f]/.test(name)) {
    fail("--name " + JSON.stringify(name) + " is not an app name");
  }
  const version = o.version ?? String(Math.floor(Date.now() / 1000));
  const short = o.short ?? "1.0";
  if (!/^\d+(\.\d+){0,2}$/.test(version) || !/^\d+(\.\d+){0,2}$/.test(short)) {
    fail("--version and --short take one to three numbers, like 12 or 1.0.2");
  }
  if (o.origin !== undefined && !/^https?:\/\/[^/\s]+/.test(o.origin)) {
    fail("--origin takes an http or https URL, like https://example.com");
  }
  return { id, name, version, short, origin: o.origin, identity: o.identity };
}

function mac_build(book: Bend.Book, out: string, o: MacOpts): void {
  const sdk = xr("xcrun", ["--sdk", "macosx", "--show-sdk-path"]);
  const sdk_ver = xr("xcrun", ["--sdk", "macosx", "--show-sdk-version"]);
  const target = "arm64-apple-macos" + MAC_MIN;
  const cc = ["--sdk", "macosx", "clang", "-target", target, "-isysroot", sdk];
  const objc = ["-x", "objective-c", "-fobjc-arc", "-fmodules"];
  const c = Comp.compile_book(book);
  if (c.split("\nint main(int argc, char** argv) {\n").length !== 2) {
    throw "Error: the runtime's C no longer has exactly one main, so -o .macos"
      + " cannot rename it bend_main: update mac_build in bend2/tool.ts";
  }
  const apple = path.join(Bend.BEND_DIR, "std/F/apple");
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "bend-macos-"));
  const dir = fs.mkdtempSync(path.join(path.dirname(path.resolve(out)), ".bend-macos-"));
  try {
    const t = (f: string): string => path.join(tmp, f);
    const app = path.join(dir, o.name + ".app");
    const exe = path.join(app, "Contents/MacOS", o.name);
    fs.mkdirSync(path.dirname(exe), { recursive: true });
    fs.mkdirSync(path.join(app, "Contents/Resources"));
    fs.writeFileSync(t("app.c"), c);
    // A program with a framework effect (#import: a window) builds as
    // Objective-C, as build does; the rest is plain C.
    xr("xcrun", [...cc, ...(/^#import /m.test(c) ? [...objc, "-fmodules-ignore-macro=main"] : []),
      "-std=c11", "-O3", "-DBEND_NATIVE=1", "-Dmain=bend_main", "-c", t("app.c"), "-o", t("app.o")]);
    for (const f of ["shell", "paint"]) {
      xr("xcrun", [...cc, ...objc, "-std=c11", "-O2", "-c", path.join(apple, f + ".c"), "-o", t(f + ".o")]);
    }
    xr("xcrun", [...cc, t("app.o"), t("shell.o"), t("paint.o"), "-lpthread", "-lm",
      ...["AppKit", "CoreText", "QuartzCore", "Foundation", "CoreImage", "ImageIO"].flatMap((f) => ["-framework", f]),
      "-o", exe]);
    const info: Record<string, unknown> = {
      CFBundleDevelopmentRegion: "en",
      CFBundleDisplayName: o.name,
      CFBundleExecutable: o.name,
      CFBundleIdentifier: o.id,
      CFBundleInfoDictionaryVersion: "6.0",
      CFBundleName: o.name,
      CFBundlePackageType: "APPL",
      CFBundleShortVersionString: o.short,
      CFBundleSupportedPlatforms: ["MacOSX"],
      CFBundleVersion: o.version,
      DTPlatformName: "macosx",
      DTSDKName: "macosx" + sdk_ver,
      LSMinimumSystemVersion: MAC_MIN,
      NSAppTransportSecurity: { NSAllowsLocalNetworking: true },
      NSHighResolutionCapable: true,
      NSPrincipalClass: "NSApplication",
      NSSupportsAutomaticGraphicsSwitching: true,
      ...(o.origin === undefined ? {} : { BendOrigin: o.origin }),
    };
    fs.writeFileSync(path.join(app, "Contents/Info.plist"), plist_xml(info));
    fs.writeFileSync(path.join(app, "Contents/PkgInfo"), "APPL????");
    xr("plutil", ["-lint", path.join(app, "Contents/Info.plist")]);
    const signer = mac_sign(app, o.identity);
    xr("codesign", ["--verify", "--strict", app]);
    fs.writeFileSync(path.join(dir, "manifest.json"), JSON.stringify({ bendMacos: 1,
      app: o.name + ".app", executable: "Contents/MacOS/" + o.name, id: o.id, name: o.name,
      version: o.version, short: o.short, origin: o.origin ?? null, target,
      sdk: sdk_ver, identity: signer.sha1, signer: signer.who,
      built: new Date().toISOString() }, null, 2) + "\n");
    fs.chmodSync(dir, 0o755);
    dir_swap(dir, out);
    say(1, path.join(out, o.name + ".app") + " (" + o.id + " " + o.version + ", "
      + signer.who + ")\n");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

// mac_sign signs the app with --identity (a SHA-1, part of a name, or -
// for ad hoc), else the first Apple Development identity, else ad hoc; a
// chosen identity that fails is an error, a found one falls back to ad hoc
function mac_sign(app: string, want?: string): { sha1: string; who: string } {
  const ids = want === "-" ? [] : [...xr("security", ["find-identity", "-v", "-p", "codesigning"])
    .matchAll(/^\s*\d+\) ([0-9A-F]{40}) "(.+)"$/gm)].map((m) => ({ sha1: m[1], who: m[2] }));
  const pick = want === "-" ? undefined : want !== undefined
    ? ids.find((x) => x.sha1 === want.toUpperCase() || x.who.includes(want))
      ?? fail("--identity " + want + " is no signing identity in the keychain"
        + " (security find-identity -v -p codesigning)")
    : ids.find((x) => x.who.startsWith("Apple Development:"));
  if (pick !== undefined) {
    const got = child.spawnSync("codesign", ["--force", "--timestamp=none", "--sign", pick.sha1, app],
      { encoding: "utf8" });
    if (got.status === 0) {
      return pick;
    }
    if (want !== undefined) {
      throw "Error: codesign with " + pick.who + " failed: " + (got.stderr ?? "").trim();
    }
    say(2, "warning: codesign with " + pick.who + " failed (" + (got.stderr ?? "").trim()
      + "), so the app is signed ad hoc\n");
  }
  xr("codesign", ["--force", "--timestamp=none", "--sign", "-", app]);
  return { sha1: "-", who: "ad hoc" };
}

// dir_swap puts a finished build at out, replacing only an earlier one
function dir_swap(dir: string, out: string): void {
  if (!fs.existsSync(out)) {
    fs.renameSync(dir, out);
    return;
  }
  let old: { bendMacos?: unknown } | null = null;
  try {
    old = JSON.parse(fs.readFileSync(path.join(out, "manifest.json"), "utf8"));
  } catch {}
  if (old?.bendMacos !== 1) {
    throw "Error: refusing to replace " + out + ", a directory without a Bend Mac manifest";
  }
  const prev = out + ".previous-" + crypto.randomBytes(6).toString("hex");
  fs.renameSync(out, prev);
  try {
    fs.renameSync(dir, out);
  } catch (e) {
    fs.renameSync(prev, out);
    throw e;
  }
  fs.rmSync(prev, { recursive: true, force: true });
}

// plist_xml writes a value as an XML property list: an object is a dict,
// an array an array, a whole number an integer
function plist_xml(v: unknown): string {
  const esc = (s: string): string => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const val = (x: unknown, pad: string): string => {
    if (typeof x === "boolean") {
      return pad + (x ? "<true/>" : "<false/>") + "\n";
    }
    if (typeof x === "number") {
      return pad + (Number.isInteger(x) ? "<integer>" + x + "</integer>" : "<real>" + x + "</real>") + "\n";
    }
    if (typeof x === "string") {
      return pad + "<string>" + esc(x) + "</string>\n";
    }
    if (Array.isArray(x)) {
      return pad + "<array>\n" + x.map((y) => val(y, pad + "\t")).join("") + pad + "</array>\n";
    }
    const ks = Object.keys(x as object).sort();
    return pad + "<dict>\n" + ks.map((k) => pad + "\t<key>" + esc(k) + "</key>\n"
      + val((x as Record<string, unknown>)[k], pad + "\t")).join("") + pad + "</dict>\n";
  };
  return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\""
    + " \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n" + val(v, "")
    + "</plist>\n";
}

// xr runs a command and answers its stdout; a failure throws its output
function xr(cmd: string, args: string[]): string {
  const got = child.spawnSync(cmd, args, { encoding: "utf8", maxBuffer: 1 << 28 });
  if (got.status !== 0) {
    throw "Error: " + [cmd, ...args].join(" ") + " failed"
      + (got.error ? ": " + got.error.message : "") + "\n" + (got.stderr ?? "") + (got.stdout ?? "");
  }
  return (got.stdout ?? "").trim();
}

// base prints the base library; with --types, its type declarations
// (every `type`, and every law whose result is a kind); with a name, the
// blocks declaring it or a name under it (its law, its def, its @unsafe).
function base(what?: string): void {
  const src = fs.readFileSync(Main.BASE, "utf8");
  if (what === undefined) {
    return say(1, src);
  }
  const want: string[] = [];
  for (const text of src.split(/\n(?=type |law |def |@)/)) {
    const m = /^(type|law|def) ([^\s(<:?]+)/m.exec(text);
    if (m === null) {
      continue;
    }
    const s = text.replace(/(\n(#[^\n]*)?)+$/, "");
    const last = s.slice(s.lastIndexOf("\n") + 1);
    const ok = what === "--types"
      ? m[1] === "type" || (m[1] === "law" && /^ *(Type|Data|Kind\(.*\))$/.test(last))
      : m[2] === what || m[2].startsWith(what + ".");
    if (ok) {
      want.push(s);
    }
  }
  if (want.length === 0) {
    fail("Base has no " + what);
  }
  say(1, want.join("\n\n") + "\n");
}

// Publish
// =======

// pkg_publish checks the file, then posts what the loader read (no TODO
// left) to the hub with its proof of work, and prints the import line.
// First it prints the terms and the license the hub will show.
async function pkg_publish(file: string, named?: string): Promise<void> {
  const seen = new Map<string, string | null>();
  const book = await Main.book_read(file, undefined, seen);
  const files = pkg_files(file, book, seen);
  const entry = Object.keys(files)[0];
  const name  = path.basename(entry, ".bend");
  if (name === "") {
    fail("a published file needs a name before .bend");
  }
  const paths = Object.keys(files).sort();
  const bytes = paths.reduce((n, p) => n + Buffer.byteLength(files[p]), 0);
  const hash  = "0x" + sha256(paths.map((p) => sha256(files[p]) + " " + p
    + "\n").join("")).slice(0, 32);
  const lic   = paths.filter((p) => path.posix.basename(p) === "LICENSE")
    .sort((a, b) => a.split("/").length - b.split("/").length)[0];
  const spdx  = lic === undefined ? undefined : files[lic].split("\n").slice(0, 5)
    .map((l) => SPDX_RE.exec(l)?.[1]).find((id) => /[A-Za-z]/.test(id ?? ""))
    ?.replace(/\s+/g, " ");
  say(2, "Publishing to BendHub: public and permanent, under " + TERMS
    + "\nLicense: " + (lic === undefined ? "MIT-0, the default (no LICENSE file): "
    + TERMS + ".4\nwarning: no file is named exactly LICENSE, so the package is"
    + " MIT-0; to license it otherwise, put the license in a file named LICENSE"
    + " beside " + entry : spdx === undefined ? "see " + lic : spdx + " (" + lic + ")") + "\n");
  const auth  = named === undefined ? null : await hub_check(named);
  say(2, "publishing " + String(paths.length) + " files, "
    + String(bytes) + " bytes, as " + hash + " (mining its proof of work)\n");
  const nonce = await pow_mine(hash, bytes);
  const res = await fetch(Bend.BEND_HUB, { method: "POST",
    headers: auth === null ? {} : { authorization: "Bearer " + auth.key },
    body: JSON.stringify({ files, nonce }) });
  if (res.status === 401) {
    key_dead();
  }
  const got = (await res.text()).trim();
  if (!res.ok || got !== hash) {
    throw "Error: " + Bend.BEND_HUB + " answered: " + got;
  }
  say(1, hash + "\n");
  if (auth !== null) {
    await hub_name(auth, hash).catch((e: unknown) => {
      throw String(e) + "\n" + hash + " is published but not named: bun bend2/tool.ts link " + auth.named + " " + hash;
    });
    say(1, "published " + auth.named + "\n");
  }
  say(1, "import " + (auth === null ? hash : auth.named) + "/" + entry + " as "
    + name[0].toUpperCase() + name.slice(1) + "\n");
}

// link names a package already on the hub
async function link(named: string, hash: string): Promise<void> {
  if (!/^0x[0-9a-f]{32}$/.test(hash)) {
    fail("link takes the package's hash: 0x and 32 hex digits");
  }
  await hub_name(await hub_check(named), hash);
  say(1, "linked " + named + " to " + hash + "\n");
}

// named_parts splits a <name>@<version>, or fails
function named_parts(named: string): [string, string] {
  const m = Bend.NAMED.exec(named);
  return m === null ? fail("a package is named <name>@<version>: a-z, 0-9 and -,"
    + " 1 to 64 characters, at four numbers like 1.0.0.0") : [m[1], m[2]];
}

// hub_check reads the key (a login when there is none), then asks the
// hub's /publish-check whose the name is and whether the version goes up
async function hub_check(named: string): Promise<{ named: string; key: string; free: boolean }> {
  const [name, version] = named_parts(named);
  let key = "";
  try {
    key = String((JSON.parse(fs.readFileSync(BENDER, "utf8")) as { key?: string }).key ?? "");
  } catch {}
  if (key === "") {
    key = await login();
  }
  const got = await hub_ask("/publish-check?name=" + name + "&version=" + version, key);
  if ((got.name !== "yours" && got.name !== "free") || got.version_ok !== true) {
    throw "Error: " + String(got.reason);
  }
  return { named, key, free: got.name === "free" };
}

// hub_name registers a free name and links name@version to a hash
async function hub_name(auth: { named: string; key: string; free: boolean }, hash: string): Promise<void> {
  const [name, version] = named_parts(auth.named);
  if (auth.free) {
    await hub_ask("/register", auth.key, { name });
    say(2, "registered " + name + "\n");
  }
  await hub_ask("/link", auth.key, { name, version, hash });
}

// hub_ask sends the key with a GET, or a POST of body, and answers the
// hub's JSON; unreachable, a refused key or a refused request ends the run
async function hub_ask(route: string, key: string, body?: unknown): Promise<Record<string, unknown>> {
  const res = await fetch(Bend.BEND_HUB + route, { method: body === undefined ? "GET" : "POST",
    headers: { authorization: "Bearer " + key, "content-type": "application/json" },
    body: JSON.stringify(body) }).catch(() => null);
  if (res === null) {
    throw "Error: " + Bend.BEND_HUB + " could not be reached";
  }
  if (res.status === 401) {
    key_dead();
  }
  const got = await res.json().catch(() => null) as Record<string, unknown> | null;
  if (!res.ok || got === null) {
    throw "Error: " + Bend.BEND_HUB + route + " answered: "
      + (typeof got?.reason === "string" ? got.reason : String(res.status));
  }
  return got;
}

// key_dead forgets a key the hub refused, so the next run logs in
function key_dead(): never {
  fs.rmSync(BENDER, { force: true });
  throw "Error: " + Bend.BEND_HUB + " does not know this login: run bun bend2/tool.ts login";
}

// login starts Bender's CLI login, opens its page and polls until the
// browser authorized a key (SPEC.md 6.14 of bend-lang.com)
async function login(): Promise<string> {
  const st = await fetch(Main.ORIGIN + "/bender/cli/start", { method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ machine: os.hostname() }) }).then((r) => r.json()).catch(() => null) as
    { poll_secret?: string; verify_url?: string; expires_at?: string; interval_ms?: number } | null;
  if (st === null || typeof st.poll_secret !== "string" || typeof st.verify_url !== "string") {
    throw "Error: " + Main.ORIGIN + " did not start a login";
  }
  say(2, "log in at " + st.verify_url + "\n");
  try {
    Bun.spawn([process.platform === "darwin" ? "open" : "xdg-open", st.verify_url], { stdout: "ignore", stderr: "ignore" });
  } catch {}
  const until = Date.parse(st.expires_at ?? "") || Date.now() + 600000;
  while (Date.now() < until) {
    await new Promise((r) => setTimeout(r, Math.max(1000, st.interval_ms ?? 2000)));
    const got = await fetch(Main.ORIGIN + "/bender/cli/poll", { method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ poll_secret: st.poll_secret }) }).then((r) => r.json()).catch(() => null) as
      { status?: string; key?: string; login?: string } | null;
    if (got?.status === "authorized" && typeof got.key === "string") {
      fs.mkdirSync(path.dirname(BENDER), { recursive: true });
      fs.writeFileSync(BENDER, JSON.stringify({ key: got.key, login: got.login ?? "" }) + "\n", { mode: 0o600 });
      say(2, "logged in as " + String(got.login ?? "") + "\n");
      return got.key;
    }
    if (got?.status === "expired") {
      break;
    }
  }
  throw "Error: the login was not authorized in time: run bun bend2/tool.ts login again";
}

// pkg_files is the package the loader read for this file, the entry first:
// every .bend file at its namespace (the entry at its name), every foreign
// .c or .js file at its path from the entry's directory; base and the
// store's packages stay out. A path that climbs above the entry's directory
// takes the entry's ancestor directories along, as many as the deepest climb.
// A LICENSE beside a published file goes along; a license/ directory, in
// any case, is refused (it clashes with LICENSE on a case-blind disk).
// A leading byte order mark is dropped: the hub stores the text as sent,
// and an importer's fetch drops the mark, so a file sent with one would
// never match its hash.
function pkg_files(file: string, book: Bend.Book,
  seen: Map<string, string | null>): Record<string, string> {
  const dir  = fs.realpathSync(path.dirname(file)) + "/";
  const raws = [...[...seen].flatMap(([real, ns]): [string, string][] =>
    real === Main.BASE || ns === null || ns.startsWith("0x") ? []
      : [[ns === "" ? path.basename(file) : ns + ".bend", real]]),
  ...Object.entries(book.tlds).flatMap(([k, tld]): [string, string][] =>
    tld.$ !== "Def" || tld.i === undefined || tld.b === true
      || k.startsWith("0x") ? [] : tld.i.map((f) =>
      [f.startsWith(dir) ? f.slice(dir.length) : f, f]))];
  const ups = raws.map(([p]) => path.posix.normalize(p).split("/")
    .filter((s) => s === "..").length);
  const anc = fs.realpathSync(path.dirname(file)).split("/")
    .slice(-Math.max(0, ...ups) || Infinity);
  const files: Record<string, string> = {};
  for (const [raw, real] of raws) {
    const p = path.posix.join(...anc, raw);
    if (p.startsWith("/") || p.startsWith("..")) {
      throw "Error: " + real + " cannot be published (an absolute import,"
        + " or a climb above the file system)";
    }
    if (p.split("/").slice(0, -1).some((s) => s.toLowerCase() === "license")) {
      throw "Error: " + real + " cannot be published: it is in a directory"
        + " named license, which clashes with a LICENSE file; rename it";
    }
    files[p] = fs.readFileSync(real, "utf8").replace(/^﻿/, "");
    if (fs.readdirSync(path.dirname(real)).includes("LICENSE")) {
      files[path.posix.join(path.posix.dirname(p), "LICENSE")] =
        fs.readFileSync(path.join(path.dirname(real), "LICENSE"), "utf8")
          .replace(/^﻿/, "");
    }
  }
  return files;
}

function sha256(text: string): string {
  return crypto.createHash("sha256").update(text).digest("hex");
}

async function pow_mine(hash: string, bytes: number): Promise<number> {
  const pow  = Number((await hub_ask("/pow.json", "")).pow);
  const step = os.availableParallelism();
  const lim  = 2 ** 53 / (pow * Math.max(1, bytes / 262144));
  const ws   = Array.from({ length: step }, (_, k) => new thr.Worker(POW_JS,
    { eval: true, workerData: { pre: hash + " ", lim, from: k, step } }));
  const n = await new Promise<number>((res) =>
    ws.forEach((w) => w.on("message", res)));
  ws.forEach((w) => w.terminate());
  return n;
}

if (import.meta.main) {
  Main.ua_fetch();
  await tool();
  process.exit();
}
