import Base

# The mobile deployment needs a persistent Codex subprocess, beyond V's static
# Web server. The fork's Process effect runs the app's build/deploy adapters.
def finished(result: Result<&1, &1, U32 & String, U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{(code, message)}: IO.die(Unit, U32.max(code, 1), message)
    case Done{(+code, (out, err))}:
      do IO<Unit>:
        printed : Unit <- IO.write(out)
        errors : Unit <- IO.print_err(err)
        Bool.pick(IO(Unit), U32.is_eq(code, 0), IO.pure(Unit, Unit{}), IO.die(Unit, code, "Open Dot command failed."))
def run(script: String) -> IO(Unit):
  IO.bind(Result<&1, &1, U32 & String, U32 & (String & String)>, Unit,
    Process.run("/bin/bash", [script], "", 1048576, 600000), finished)
def command(args: List<String>) -> IO(Unit):
  match args:
    case "build" <> Nil{}: run("./script/build_mobile.sh")
    case "deploy" <> Nil{}: run("./script/deploy_mobile.sh")
    case _: IO.die(Unit, 2, "usage: bend system build | deploy")
def invoked(args: List<String>) -> IO(Unit):
  match args:
    case program <> rest: command(rest)
    case _: command([])
def main() -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), invoked)
