import UI
import ../mobile.bend as App
import ../ios.bend as IOS
import ../../../bend2/std/F/browser/host.bend as Host
import ../../../bend2/std/F/ai/wire_json.bend as J

def tick() -> J.Json:
  J.Object{[J.Field{"phase", J.Text{"elapsed"}}, J.Field{"elapsedMs", J.Number{"2500"}}, J.Field{"level", J.Number{"70"}}]}

def main() -> IO(Unit):
  +ready = App.apply_reply(App.s(), Host.Reply{1, "{\"threads\":[{\"id\":\"voice-test\",\"title\":\"Near\",\"status\":\"working\",\"messages\":[]}],\"selectedThreadId\":\"voice-test\"}"}, False{})
  +recording = App.State.with_panel(App.with_voice(ready, App.Voice{"recording", "clip", 0, "", 0}), App.Recording{})
  +stopping = App.with_voice(recording, App.Voice{"sending-recording", "clip", 1000, "", 0})
  +before = App.apply_reply(ready, Host.Reply{1, "{\"threads\":[{\"id\":\"voice-test\",\"title\":\"Near\",\"status\":\"idle\",\"messages\":[{\"role\":\"assistant\",\"text\":\"Keep this message\"}],\"historyBefore\":\"4\",\"historyHasMore\":true,\"historyIsLatest\":false}],\"selectedThreadId\":\"voice-test\"}"}, False{})
  +candidate = App.State.with_draft(ready, "new snapshot")
  +deferred = IOS.commit_refresh(before, candidate, Host.Reply{3, "conversation refresh deferred"})
  +accepted = IOS.commit_refresh(before, candidate, Host.Reply{1, ""})
  +timedout = IOS.commit_refresh(before, candidate, Host.Reply{3, "request timeout"})
  +failed = IOS.commit_refresh(before, candidate, Host.Reply{2, "invalid Canvas JSON"})
  do IO<Unit>:
    # The stock test host returns an error for network IO. Recording must not call it.
    +refreshed : App.State <- App.refresh(recording, App.Recording{})
    IO.print(Bool.show(App.State.online(refreshed)))
    IO.print(Bool.show(String.is_empty(App.State.error(refreshed))))
    IO.print(Bool.show(String.eq(App.voice_phase(refreshed), "recording")))
    +ticked : App.State <- App.voice_message_event(stopping, tick())
    IO.print(Bool.show(String.eq(App.voice_phase(ticked), "sending-recording")))
    IO.print(Bool.show(U32.is_eq(App.voice_duration(ticked), 2500)))
    IO.print(Bool.show(String.eq(App.Thread.historyBefore(App.current(deferred)), "4")))
    IO.print(Bool.show(String.eq(App.State.draft(accepted), "new snapshot")))
    IO.print(Bool.show(String.eq(App.State.error(failed), "invalid Canvas JSON")))
    IO.print(Bool.show(String.eq(App.State.error(timedout), "request timeout")))
    IO.print(Bool.show(Bool.not(App.Thread.historyIsLatest(App.current(deferred)))))
    +camera : App.State <- App.take_photo(ready)
    IO.print(Bool.show(Bool.not(App.has_photo(camera))))
    IO.print(Bool.show(Bool.not(String.is_empty(App.State.error(camera)))))

#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
