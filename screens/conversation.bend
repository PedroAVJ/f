import UI
import ../components/log
import ../components/composer

def conversation(history: List<&2, Line>, busy: Bool) -> UI:
  screen([
    title(Text{"Dot", "Dot"}),
    log(history, busy),
    composer()])
