// WASI fd_write: own browser output buffers instead of an unbounded tty line.
addToLibrary({
  fd_write__deps: [],
  fd_write__postset: '',
  fd_write: function(fd, iov, count, written) {
    if (fd !== 1 && fd !== 2) return 8;
    var total = 0;
    for (var i = 0; i < count; i++, iov += 8) {
      var ptr = HEAPU32[iov >>> 2], len = HEAPU32[(iov + 4) >>> 2];
      if (len > 1048576 || ptr + len > HEAPU8.length) throw Error('browser output exceeds 1 MiB');
      var bytes = HEAPU8.slice(ptr, ptr + len);
      if (Module.bendWrite) Module.bendWrite(fd, bytes);
      else {
        var text = new TextDecoder().decode(bytes).replace(/\n$/, '');
        (fd === 1 ? out : err)(text);
      }
      total += len;
    }
    HEAPU32[written >>> 2] = total;
    return 0;
  }
});
