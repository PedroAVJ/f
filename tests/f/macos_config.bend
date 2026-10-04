# Optional native hooks select the generated entry; the default entry and
# web entry keep their existing rendering and input behavior.
import Base
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def selected(+file: String, source: String) -> IO(Unit):
  do IO<Unit>:
    wrote : Verbs.Ran <- Verbs.sh("printf '%s' \"$1\" > \"$2.bend\"", [source, file], "")
    choice : Verbs.Ran <- Verbs.sh(Verbs.app_script() ++ "printf '%s' \"$e\"",
      ["page", "build", "light", "com.bend.fixture", file, "dark", "persist", "both",
       "window", "dark-window", "persist-window", "both-window"], "")
    IO.print(Verbs.out(choice))

def main() -> IO(Unit):
  do IO<Unit>:
    build_syntax : Verbs.Ran <- Verbs.sh("/bin/sh -n", [], Verbs.app_build_script())
    stamp_syntax : Verbs.Ran <- Verbs.sh("/bin/sh -n", [], Verbs.app_stamp_script())
    IO.print(Bool.show(Verbs.ok(build_syntax) && Verbs.ok(stamp_syntax)))
    IO.print(Bool.show(String.contains(Verbs.native_entry_in("ui", True{}),
      "Native.show_canvas_in(Ui.f(s), Rendering{Ui.State.lang(s), k}, Ui.scheme())")))
    IO.print(Bool.show(String.contains(Verbs.native_entry_config("ui", False{}, True{}),
      "u : Unit <- Native.configure_input_persistence(Ui.persist_inputs())")))
    IO.print(Bool.show(String.eq(Verbs.native_entry("ui"), Verbs.native_entry_config("ui", False{}, False{}))))
    IO.print(Bool.show(String.contains(Verbs.native_entry_options("ui", True{}, True{}, True{}),
      "w : Unit <- Native.configure_window(Ui.window())") &&
      String.contains(Verbs.native_entry_options("ui", True{}, True{}, True{}), "case _:\n      Ui.update(s, i)")))
    temp : Verbs.Ran <- Verbs.sh("mktemp -d /tmp/bend_io_macos_config.XXXXXX", [], "")
    +dir : String = String.trim(Verbs.out(temp))
    selected(dir ++ "/ui", "# def scheme():\n# def persist_inputs():\n")
    selected(dir ++ "/ui", "def scheme() -> T.Scheme:\n  T.Dark{}\n")
    selected(dir ++ "/ui", "def persist_inputs() -> Bool:\n  False{}\n")
    selected(dir ++ "/ui", "def scheme() -> T.Scheme:\n  T.Dark{}\ndef persist_inputs() -> Bool:\n  False{}\n")
    selected(dir ++ "/ui", "# def window():\n")
    selected(dir ++ "/ui", "def window() -> Native.WindowConfig:\n  Native.WindowConfig{1000,760,640,560}\n")
    selected(dir ++ "/ui", "def scheme() -> T.Scheme:\n  T.Dark{}\ndef window() -> Native.WindowConfig:\n  Native.WindowConfig{1000,760,640,560}\n")
    selected(dir ++ "/ui", "def persist_inputs() -> Bool:\n  False{}\ndef window() -> Native.WindowConfig:\n  Native.WindowConfig{1000,760,640,560}\n")
    selected(dir ++ "/ui", "def scheme() -> T.Scheme:\n  T.Dark{}\ndef persist_inputs() -> Bool:\n  False{}\ndef window() -> Native.WindowConfig:\n  Native.WindowConfig{1000,760,640,560}\n")
    clean : Verbs.Ran <- Verbs.sh("rm -rf \"$1\"", [dir], "")
    return Unit{}
#|True
#|True
#|True
#|True
#|True
#|light
#|dark
#|persist
#|both
#|light
#|window
#|dark-window
#|persist-window
#|both-window
