# A foreign installed bundle blocks before any staging, replacement or
# process/UI action. The fixture mocks filesystem observations and refuses
# every mutating command, so running this test never installs an app.
import Base
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def fixture() -> String:
  "foreign=\"$HOME/Applications/Fixture.app\"\n" ++
  "fixture_test() {\n" ++
  "  if test \"$#\" -eq 4 && test \"$1\" = '!' && test \"$2\" = '-e' && test \"$3\" = \"$foreign\"; then return 1; fi\n" ++
  "  if test \"$#\" -eq 3 && test \"$1\" = '-e' && test \"$2\" = \"$foreign\"; then return 0; fi\n" ++
  "  case $# in 2) test \"$1\";; 3) test \"$1\" \"$2\";; 4) test \"$1\" \"$2\" \"$3\";; 5) test \"$1\" \"$2\" \"$3\" \"$4\";; *) return 99;; esac\n" ++
  "}\n" ++
  "alias \"[\"=fixture_test\n" ++
  "plutil() { case \"$2\" in CFBundleIdentifier) if test \"$6\" = 'build/Fixture.app/Contents/Info.plist'; then echo com.bend.fixture; else echo com.other.fixture; fi;; CFBundleVersion) echo 101;; *) return 99;; esac; }\n" ++
  "unsafe() { echo \"unsafe command: $1\" >&2; return 99; }\n" ++
  "mkdir() { unsafe mkdir; }; mktemp() { unsafe mktemp; }; ditto() { unsafe ditto; }; codesign() { unsafe codesign; }\n" ++
  "lsappinfo() { unsafe lsappinfo; }; kill() { unsafe kill; }; mv() { unsafe mv; }; open() { unsafe open; }; rm() { unsafe rm; }\n"

def rejected(r: Verbs.Ran) -> Bool:
  match r:
    case Verbs.Ran{code, _, +err}:
      U32.is_eq(code, 1) && String.contains(err, "Fixture.app is another app; not replacing it") &&
        Bool.not(String.contains(err, "unsafe command"))

def main() -> IO(Unit):
  do IO<Unit>:
    syntax : Verbs.Ran <- Verbs.sh("/bin/sh -n", [], Verbs.install_script())
    IO.print(Bool.show(Verbs.ok(syntax)))
    collision : Verbs.Ran <- Verbs.sh(fixture() ++ Verbs.install_script(),
      ["build/Fixture.app", "com.bend.fixture", "101"], "")
    IO.print(Bool.show(rejected(collision)))
#|True
#|True
