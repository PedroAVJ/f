// Window
// ======

function window_open(title, width, height) {
  const code = process.platform === "darwin" ? 45 : 95;
  const text = "Window.open: no display (a window opens in a native build, run from a desktop session)";
  return { $: CID(Fail), error: io_tup(code, text) };
}

io_eff(CID(Window.open), window_open);
