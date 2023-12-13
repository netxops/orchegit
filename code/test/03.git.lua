--!/usr/bin/lua
git = resource.git.new("/tmp/graphviz")
git.url = "https://gitlab.com/graphviz/graphviz.git"
git.proxy = "http://10.45.7.145:8118"

catalog:add(git)
