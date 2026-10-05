import UI
import ../../f/bend2/std/F/browser/input.bend as Native
import ../../f/bend2/std/F/browser/host.bend as Host
import ../../f/bend2/std/F/browser/scene.bend as Scene
import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../mobile.bend as App

def html(state: App.State) -> String:
  Scene.html_in(K.draw(App.f(state), K.Rendering{K.Lang.Es{}, []}), T.Scheme.Dark{})
def notice_text(panel: App.Panel) -> String:
  match panel:
    case App.Notice{text}: text
    case _: ""
def main() -> IO(Unit):
  +typed = App.update(App.s(), Native.Typed{"Mensaje", "Unsent draft"})
  +menu = App.State.with_panel(typed, App.Menu{})
  +bakery = App.State.with_session(menu, App.Snapshot{[], "", [], "bakery"})
  +native = App.notification_settings_reply(menu, Host.Reply{1, ""})
  +web = App.notification_settings_reply(menu, Host.Reply{1, "Notifications are available in the iPhone app."})
  do IO<Unit>:
    IO.print(Bool.show(String.contains(html(menu), "Notificaciones")))
    IO.print(Bool.show(Bool.not(String.contains(html(bakery), "Notificaciones"))))
    IO.print(Bool.show(App.is_menu(App.State.panel(native))))
    IO.print(Bool.show(String.eq(App.State.draft(native), "Unsent draft")))
    IO.print(Bool.show(String.eq(App.State.draft(web), "Unsent draft")))
    IO.print(Bool.show(String.eq(notice_text(App.State.panel(web)), "Notifications are available in the iPhone app.")))
#|True
#|True
#|True
#|True
#|True
#|True
