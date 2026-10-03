// Spliced by Bend's JS compiler; this leaf delegates raw transport only.
function native_reply(operation, args) {
  const host = globalThis[Symbol.for('near-v.native-host.v1')];
  const failure = () => ({ $: CID(Reply), status: 4, handle: 0, data: 'transport unavailable' });
  if (!host || typeof host.dispatch !== 'function') return failure();
  const asyncMode = host.async === true;
  if (asyncMode && globalThis[Symbol.for('near-v.native-io.async.v1')] !== true) return failure();
  function pack(reply) {
    if (!reply || !Number.isInteger(reply.status) || reply.status < 1 || reply.status > 4
      || !Number.isInteger(reply.handle) || reply.handle < 0 || reply.handle > 0xffffffff
      || typeof reply.data !== 'string') return failure();
    return { $: CID(Reply), status: reply.status, handle: reply.handle, data: reply.status === 4 ? 'transport failed' : reply.data };
  }
  try {
    const reply = host.dispatch(operation, args);
    if (asyncMode) return Promise.resolve(reply).then(pack, failure);
    // The stock Bend IO loop is synchronous; never accept a Promise as a value.
    if (reply && typeof reply.then === 'function') { reply.catch?.(() => {}); return failure(); }
    if (!reply
      || !Number.isInteger(reply.status) || reply.status < 1 || reply.status > 4
      || !Number.isInteger(reply.handle) || reply.handle < 0 || reply.handle > 0xffffffff
      || typeof reply.data !== 'string') return failure();
    return { $: CID(Reply), status: reply.status, handle: reply.handle, data: reply.status === 4 ? 'transport failed' : reply.data };
  } catch { return failure(); }
}
io_eff(CID(http_open_raw), (...args) => native_reply('http.open', args.slice(0, 5)));
io_eff(CID(stream_read_raw), (...args) => native_reply('stream.read', args.slice(0, 1)));
io_eff(CID(socket_open_raw), (...args) => native_reply('socket.open', args.slice(0, 3)));
io_eff(CID(socket_send_raw), (...args) => native_reply('socket.send', args.slice(0, 2)));
io_eff(CID(process_open_raw), (...args) => native_reply('process.open', args.slice(0, 4)));
io_eff(CID(process_write_raw), (...args) => native_reply('process.write', args.slice(0, 2)));
io_eff(CID(transport_close_raw), (...args) => native_reply('transport.close', args.slice(0, 1)));
