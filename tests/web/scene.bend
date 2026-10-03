import Base
import ../../bend2/std/F/browser/scene.bend as Scene

def main() -> String:
  Scene.escape("<b>&\"'🐈</b>")
#|"&lt;b&gt;&amp;&quot;&#39;🐈&lt;/b&gt;"
