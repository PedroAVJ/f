import UI

# The conversation so far, plus "Dot is typing…" while waiting.
def log(history: List<&2, Line>, busy: Bool) -> UI:
  stack(List.append(&1, UI, lines(history), Bool.pick(List<UI>, busy, [caption(Text{"Dot is typing…", "Dot está escribiendo…"})], [])))
