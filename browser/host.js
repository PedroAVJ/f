// The stock JS IO loop is synchronous. Browser async effects run in Wasm.
io_eff(CID(request), () => ({$: CID(Reply), status: 2, data: 'browser host unavailable'}));
