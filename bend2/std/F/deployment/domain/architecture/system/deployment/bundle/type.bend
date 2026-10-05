import Base

# A Mac app V builds and installs for this Mac's user: a UI module's s, update and f (ui, its path without
# ".bend") built by the fork's tool into dir (dist/<app>.macos) as <Name>.app, its name the first screen's
# first text and its bundle identifier id; installed in ~/Applications, and opened again when it changes.
type MacApp is Data:
  MacApp{ui: String, id: String, dir: String}
