# a def of the importing file may not share a name an import with no alias
# brings: the error names both
import ./bare/shapes

def area(+x: U32) -> U32: x
def main() -> IO(Unit):
  IO.print(U32.show(area(3)))
#|SOME PROOFS FAIL
#|Error:
#|- message  : an unambiguous name area (this file defines it, and import ./bare/shapes brings it)
#|Location:
#|2 | # brings: the error names both
#|3>| import ./bare/shapes
#|  |        ^
#|4 |
#|exit 1
