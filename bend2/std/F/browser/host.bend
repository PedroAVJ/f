import Base

# Browser request completion: 1 success, 2 error, 3 cancelled.
# Text crosses as length-delimited UTF-8, at most 1 MiB per message.
type Reply is Data:
  Reply{status: U32, data: String}

def request(operation: U32, data: String) -> IO(Reply):
  import "./host.c"
  import "./host.js"

def render(html: String) -> IO(Reply): request(1, html)
def event() -> IO(Reply): request(2, "")
def fetch(url: String) -> IO(Reply): request(3, url)
def canvas(commands: String) -> IO(Reply): request(4, commands)

# JSON envelope {url,body}; browser IO only.
def post(envelope: String) -> IO(Reply): request(6, envelope)
