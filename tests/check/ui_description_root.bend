import Base
import F
import ../../bend2/std/F/ui/description.bend as FUI

def main() -> FUI.UI<Tree>:
  FUI.UI{7}

#|SOME PROOFS FAIL
#|Error:
#|- expected : Tree
#|- observed : U32
#|Location: main
#|5 | def main() -> FUI.UI<Tree>:
#|6>|   FUI.UI{7}
#|  |          ^
#|7 | 
#|exit 1
