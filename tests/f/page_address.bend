# A file importing UI that defines a Page gets its addresses from its shape:
# Page.url(p) and Page.at(address). A case is its kebab-case name, then its
# String and U32 fields as segments, a nested page (a Data type of the file,
# last) as its own path; an unknown or short address reads as the first
# case. A State with a `page: Page` field gets State.page,
# State.with_page and State.lang (its `lang: Lang` field, else English)
import UI

type Tab is Data:
  Profile{}
  Billing{}

type Page is Data:
  Home{}
  Conversation{id: String}
  Order{shop: String, number: U32}
  Settings{tab: Tab}

type State is Data:
  State{name: String, page: Page}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Page.url(Conversation{"42"}) ++ " " ++ Page.url(Settings{Billing{}}) ++ " " ++ Page.url(Order{"a b", 7}) ++ " " ++ Page.url(Home{}))
    IO.print(Page.url(Page.at("/conversation/42")) ++ " " ++ Page.url(Page.at("/settings/billing")) ++ " " ++ Page.url(Page.at("/order/a%20b/7?x")))
    IO.print(Page.url(Page.at("/nowhere")) ++ " " ++ Page.url(Page.at("/")) ++ " " ++ Page.url(Page.at("/settings")) ++ " " ++ Page.url(Page.at("/order/x/y")))
    IO.print(Page.url(State.page(State.with_page(State{"ana", Home{}}, Page.at("/conversation/7")))))
    IO.print(Lang.pick(State.lang(State{"ana", Home{}}), "es", "en"))
#|/conversation/42 /settings/billing /order/a%20b/7 /home
#|/conversation/42 /settings/billing /order/a%20b/7
#|/home /home /settings/profile /order/x/0
#|/conversation/7
#|en
