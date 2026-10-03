#if BEND_WEB
EM_ASYNC_JS(uintptr_t, browser_request, (unsigned op, const char* data, unsigned len), {
  let r;
  try { r = await Module.bendRequest(op, new TextDecoder().decode(HEAPU8.slice(data, data + len))); }
  catch (e) { r = {status: 2, data: String(e?.message || e)}; }
  if (!r || ![1,2,3].includes(r.status) || typeof r.data !== 'string') r = {status: 2, data: 'invalid host reply'};
  let bytes = new TextEncoder().encode(r.data);
  if (bytes.length > 1048576) { r.status = 2; bytes = new TextEncoder().encode('reply exceeds 1 MiB'); }
  const p = _malloc(bytes.length + 8);
  if (!p) throw new Error('browser reply allocation failed');
  HEAPU32[p >>> 2] = r.status;
  HEAPU32[(p + 4) >>> 2] = bytes.length;
  HEAPU8.set(bytes, p + 8);
  return p;
});
#endif

static Term browser_run(Env e, Term* f, IoWork* w) {
  u64 len;
  char* text = io_cstr(e, f[1], &len);
  u32 status = 2;
  Term data;
#if BEND_WEB
  if (len > 1048576) {
    data = io_str(e, "request exceeds 1 MiB", 21);
  } else {
    u32* packet = (u32*)browser_request((u32)f[0], text, (unsigned)len);
    status = packet[0];
    data = io_str(e, (char*)(packet + 2), packet[1]);
    free(packet);
  }
#else
  data = io_str(e, "browser host unavailable", 24);
#endif
  free(text);
  return io_node(e, CID(Reply), status, data);
}
static void __attribute__((constructor)) browser_use(void) {
  io_eff(CID(request), browser_run, 0);
}
