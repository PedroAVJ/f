# F's host module is its one trusted boundary: nine raw transport effects
# (JS only: a program that reaches one builds with -o x.js, not to C) and
# the typed wrappers over them, so the verdict lists exactly these
import Base
import ../../bend2/std/F/ai/native-host/host.bend as Host

#|SOME PROOFS FAIL
#|Error: 18 defs rely on unsafe or foreign code:
#|- std/F/ai/native-host/host.http_open_raw
#|- std/F/ai/native-host/host.stream_read_raw
#|- std/F/ai/native-host/host.socket_open_raw
#|- std/F/ai/native-host/host.socket_send_raw
#|- std/F/ai/native-host/host.process_open_raw
#|- std/F/ai/native-host/host.process_write_raw
#|- std/F/ai/native-host/host.transport_close_raw
#|- std/F/ai/native-host/host.HTTP.open
#|- std/F/ai/native-host/host.Stream.read
#|- std/F/ai/native-host/host.Socket.open
#|- std/F/ai/native-host/host.Socket.send
#|- std/F/ai/native-host/host.Process.open
#|- std/F/ai/native-host/host.Process.write
#|- std/F/ai/native-host/host.Transport.close
#|- std/F/ai/native-host/host.stream_read_bytes_raw
#|- std/F/ai/native-host/host.Stream.read_bytes
#|- std/F/ai/native-host/host.http_multipart_open_raw
#|- std/F/ai/native-host/host.HTTP.multipart_open
#|exit 1
