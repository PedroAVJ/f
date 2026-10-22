import Base

# A pure UI description, parameterized by its renderer's data vocabulary.
# Applications own their State; this value holds no component state or effects.
type UI<-Description: Data> is Data:
  UI{root: Description}

def root(-Description: Data, ui: UI<Description>) -> Description:
  match ui:
    case UI{root}: root
