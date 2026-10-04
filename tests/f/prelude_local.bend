import Base
import UI

type Message is Data:
  Message{text: String}
def text(m: Message) -> String:
  match m:
    case Message{text}: text
def main() -> IO(Unit): IO.print(text(Message{"local"}))
#|local
