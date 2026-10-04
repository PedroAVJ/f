# A native build is current only for its recorded inputs, bundle identity
# and bytes. In particular a new, untracked native host file in the fork
# must invalidate the stamp when it changes, even from another cwd.
import Base
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def fixture() -> String:
  "mkdir -p \"$2/../fork/bend2/std/F/apple\" \"$2/FixtureApp.app/Contents\" || exit 1\n" ++
  "printf '%s' stub > \"$2/../fork/bend2/main.ts\"; git -C \"$2/../fork\" init -q && git -C \"$2/../fork\" add . && git -C \"$2/../fork\" -c user.name=Bend -c user.email=bend@local -c commit.gpgsign=false commit -qm fixture || exit 1\n" ++
  "printf '%s' first > \"$2/../fork/bend2/std/F/apple/fixture.c\"\n" ++
  "printf '%s' '<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>com.bend.fixture</string><key>CFBundleVersion</key><string>101</string></dict></plist>' > \"$2/FixtureApp.app/Contents/Info.plist\"\n" ++
  "BEND=\"$2/../fork/bend2/main.ts\"\n"

def args(+dir: String, id: String) -> List<&2, String>:
  ["page", dir ++ "/build", "native", id, dir ++ "/ui", "dark", "persist", "both"]

# Keep the compiler fixture separate from the built folder: the native
# stamp hashes the fork's sources independently from the app's bytes.
def stamp(+dir: String, +id: String) -> IO(Verbs.Ran):
  Verbs.sh("BEND=\"$2/../fork/bend2/main.ts\"\n" ++ Verbs.app_stamp_script(), args(dir, id), "")

def seen(r: Verbs.Ran) -> String:
  Verbs.line(Verbs.lines(r), 0n)

def main() -> IO(Unit):
  do IO<Unit>:
    temp : Verbs.Ran <- Verbs.sh("mktemp -d /tmp/bend_io_macos_stamp.XXXXXX", [], "")
    +dir : String = String.trim(Verbs.out(temp))
    made : Verbs.Ran <- Verbs.sh(fixture() ++ Verbs.app_script() ++
      "printf '%s\\n%s\\n101\\nFixtureApp\\n' \"$(k \"$1\" \"$e\" \"$4\")\" \"$(o \"$2\")\" > \"$2.stamp\"", args(dir, "com.bend.fixture"), "")
    IO.print(Bool.show(Verbs.ok(made)))
    fresh : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(fresh))
    themed : Verbs.Ran <- Verbs.sh("printf '%s' 'def scheme() -> T.Scheme:' > \"$1/ui.bend\"", [dir], "")
    theme : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(theme))
    retheme : Verbs.Ran <- Verbs.sh("BEND=\"$2/../fork/bend2/main.ts\"\n" ++ Verbs.app_script() ++
      "printf '%s\\n%s\\n101\\nFixtureApp\\n' \"$(k \"$1\" \"$e\" \"$4\")\" \"$(o \"$2\")\" > \"$2.stamp\"", args(dir, "com.bend.fixture"), "")
    themed_fresh : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(themed_fresh))
    unthemed : Verbs.Ran <- Verbs.sh("rm -f \"$1/ui.bend\"", [dir], "")
    old_theme : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(old_theme))
    restamp : Verbs.Ran <- Verbs.sh("BEND=\"$2/../fork/bend2/main.ts\"\n" ++ Verbs.app_script() ++
      "printf '%s\\n%s\\n101\\nFixtureApp\\n' \"$(k \"$1\" \"$e\" \"$4\")\" \"$(o \"$2\")\" > \"$2.stamp\"", args(dir, "com.bend.fixture"), "")
    identity : Verbs.Ran <- stamp(dir, "com.bend.different")
    IO.print(seen(identity))
    changed : Verbs.Ran <- Verbs.sh("printf '%s' second > \"$1/fork/bend2/std/F/apple/fixture.c\"", [dir], "")
    source : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(source))
    restore : Verbs.Ran <- Verbs.sh("printf '%s' first > \"$1/fork/bend2/std/F/apple/fixture.c\"; printf '%s' changed >> \"$1/build/FixtureApp.app/Contents/Info.plist\"", [dir], "")
    bytes : Verbs.Ran <- stamp(dir, "com.bend.fixture")
    IO.print(seen(bytes))
    clean : Verbs.Ran <- Verbs.sh("rm -rf \"$1\"; rm -f \"$1.stamp\"", [dir], "")
    return Unit{}
#|True
#|fresh
#|stale
#|fresh
#|stale
#|stale
#|stale
#|stale
