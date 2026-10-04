# two imports with no alias may not bring one name: the error names both
import ./bare/shapes
import ./bare/area

def main() -> IO(Unit):
  IO.print("never")
#|SOME PROOFS FAIL
#|Error:
#|- message  : an unambiguous binding area (import ./bare/shapes and import ./bare/area both bind it)
#|Location:
#|2 | import ./bare/shapes
#|3>| import ./bare/area
#|  |        ^
#|4 |
#|exit 1
