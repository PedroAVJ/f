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
#elif BEND_NATIVE
// A native app (tool.ts -o <dir>.macos, -DBEND_NATIVE=1) links a shell
// that answers each request as the browser's shell.js does, with the same
// reply text: bend_native_request blocks until it has the reply (on an IO
// helper thread, so the event loop and other effects go on) and returns it
// as malloc'd UTF-8, which the caller frees.
extern char* bend_native_request(unsigned op, const char* data, unsigned len,
  unsigned* status);

static void browser_call(IoWork* w) {
  unsigned status = 2;
  char*    reply  = bend_native_request(w->word, w->text, (unsigned)w->size,
    &status);
  u64      n      = reply != NULL ? strlen(reply) : 0;
  const char* why = reply == NULL || status < 1 || status > 3
    ? "invalid host reply" : n > 1048576 ? "reply exceeds 1 MiB" : NULL;
  free(w->text);
  w->text = NULL;
  if (why != NULL) {
    free(reply);
    reply  = io_mem(strdup(why));
    n      = strlen(why);
    status = 2;
  }
  w->data = reply;
  w->size = n;
  w->made = (intptr_t)status;
}

static Term browser_pack(Env e, IoWork* w) {
  Term data = io_str(e, w->data, w->size);
  free(w->data);
  w->data = NULL;
  return io_node(e, CID(Reply), (u32)w->made, data);
}
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
#elif BEND_NATIVE
  if (len <= 1048576) {
    w->word = (u32)f[0];
    w->text = text;
    w->size = len;
    return io_work(w, browser_call, browser_pack);
  }
  data = io_str(e, "request exceeds 1 MiB", 21);
#else
  data = io_str(e, "browser host unavailable", 24);
#endif
  free(text);
  return io_node(e, CID(Reply), status, data);
}
static void __attribute__((constructor)) browser_use(void) {
  io_eff(CID(request), browser_run, 0);
}
