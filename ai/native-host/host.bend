# Server-only raw transport boundary. No provider protocol or secret values here.
import Base

type ByteReply is Data:
  ByteReply{status: U32, handle: U32, bytes: List<&2, U32>}

type FormField is Data:
  FormField{name: String, value: String}

type Reply is Data:
  Reply{status: U32, handle: U32, data: String}

# Status: 1 success, 2 EOF, 3 pending, 4 failure. Data is opaque text; binary framing requires explicit encoding.
def http_open_raw(credential: U32, method: String, url: String, headers: String, body: String) -> IO(Reply):
  import "./effects.js"

def stream_read_raw(handle: U32) -> IO(Reply):
  import "./effects.js"

def socket_open_raw(credential: U32, url: String, headers: String) -> IO(Reply):
  import "./effects.js"

def socket_send_raw(handle: U32, data: String) -> IO(Reply):
  import "./effects.js"

def process_open_raw(credential: U32, executable: String, args: String, input: String) -> IO(Reply):
  import "./effects.js"

def process_write_raw(handle: U32, data: String) -> IO(Reply):
  import "./effects.js"

def transport_close_raw(handle: U32) -> IO(Reply):
  import "./effects.js"

# Filled wrappers compose in Bend programs; standard .mjs library emission omits IO defs.
def HTTP.open(credential: U32, method: String, url: String, headers: String, body: String) -> IO(Reply):
  http_open_raw(credential, method, url, headers, body)

def Stream.read(handle: U32) -> IO(Reply):
  stream_read_raw(handle)

def Socket.open(credential: U32, url: String, headers: String) -> IO(Reply):
  socket_open_raw(credential, url, headers)

def Socket.send(handle: U32, data: String) -> IO(Reply):
  socket_send_raw(handle, data)

def Process.open(credential: U32, executable: String, args: String, input: String) -> IO(Reply):
  process_open_raw(credential, executable, args, input)

def Process.write(handle: U32, data: String) -> IO(Reply):
  process_write_raw(handle, data)

def Transport.close(handle: U32) -> IO(Reply):
  transport_close_raw(handle)

def stream_read_bytes_raw(handle: U32) -> IO(ByteReply):
  import "./bytes.js"

def Stream.read_bytes(handle: U32) -> IO(ByteReply):
  stream_read_bytes_raw(handle)

# Generic physical multipart: provider field names/values are supplied by Bend.
def http_multipart_open_raw(credential: U32, url: String, headers: String, fields: List<&2, FormField>, filename: String, mime_type: String, bytes: List<&2, U32>) -> IO(Reply):
  import "./multipart.js"

def HTTP.multipart_open(credential: U32, url: String, headers: String, fields: List<&2, FormField>, filename: String, mime_type: String, bytes: List<&2, U32>) -> IO(Reply):
  http_multipart_open_raw(credential, url, headers, fields, filename, mime_type, bytes)
