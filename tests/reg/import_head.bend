# regression (AUDIT 6a): a malformed import head gets the import
# diagnostic, not the parser's 'expected def/type/assert' pointing at
# the i
import Wat
law main:
  Nat

def main():
  1n

#|SOME PROOFS FAIL
#|Error:
#|- expected : an import ('import F', 'import State', or 'import <path> as <Name>'; Base is always there, V in system.bend)
#|- observed : 'import Wat'
#|Location:
#|3 | # the i
#|4>| import Wat
#|  |        ^
#|5 | law main:
#|exit 1
# no-base
