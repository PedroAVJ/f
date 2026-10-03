import Base
import ../../bend2/std/F/browser/host.bend as Host

def show(label: String, reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{status, data}: IO.print(label ++ ":" ++ U32.show(status) ++ ":" ++ data)
def main() -> IO(Unit):
  do IO<Unit>:
    good : Host.Reply <- Host.fetch("./message.txt")
    done : Unit <- show("success", good)
    bad : Host.Reply <- Host.fetch("./missing.txt")
    done : Unit <- show("failure", bad)
    invalid : Host.Reply <- Host.request(99, "")
    done : Unit <- show("unsupported", invalid)
    slow : Host.Reply <- Host.fetch("./slow.txt")
    show("cancel", slow)
#|success:2:browser host unavailable
#|failure:2:browser host unavailable
#|unsupported:2:browser host unavailable
#|cancel:2:browser host unavailable
