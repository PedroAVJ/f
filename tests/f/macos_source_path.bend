# Generated native entries resolve from the selected compiler, not a sibling checkout.
import Base
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def check(fork: String, output: String, expected: String) -> IO(Unit):
  do IO<Unit>:
    +result : Verbs.Ran <- Verbs.sh("f=$1; d=$2; e=$3\n" ++ Verbs.native_import_script() ++ "printf '%s' \"$e\"",
      [fork, output, Verbs.native_entry("ui")], "")
    IO.print(Bool.show(Verbs.ok(result) && String.contains(Verbs.out(result), "import " ++ expected ++ " as Native")))
def main() -> IO(Unit):
  do IO<Unit>:
    check("../sibling-f/bend2", "dist/mac.macos", "../../sibling-f/bend2/std/F/browser/input.bend")
    check("../../bend2", "dist/mac.macos", "../../../bend2/std/F/browser/input.bend")
    check("compiler/bend2", "output/deeper/mac.macos", "../../compiler/bend2/std/F/browser/input.bend")
#|True
#|True
#|True
