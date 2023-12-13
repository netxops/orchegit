--!/usr/bin/lua
--!/usr/bin/lua
graphviz_version = "2.50.0"
proxy = "http://10.45.7.145:8118"
sample_config = "/home/jacky/juno/config/juno-pprof.yml"
app_path = "/home/www/system/pprof"
--------------------------------------------------------------------------------
-- prepare = resource.phase.new("prepare")
--
-- package_list = {"flex", "build-essential", "libgd-dev", "libpango1.0-dev", "checkinstall"}
-- prev = ""
-- for i, name in ipairs(package_list) do
  -- p = resource.apt.new(name)
  -- if (prev == "") then
    -- prev = p
  -- else
    -- p.require = { prev:ID() }
    -- prev = p
  -- end
  -- prepare:add(p)
-- end
--
prepare = resource.apt.new("flex")

groupadd_pprof = resource.group.new("www")
groupadd_pprof.system = true


useradd_pprof = resource.user.new("www")
useradd_pprof.require = { groupadd_pprof:ID() }
useradd_pprof.group ="www"
useradd_pprof.system = true
useradd_pprof.nologin = true
useradd_pprof.home = "/home/www"

app_home = resource.directory.new(app_path)
app_home.require = { useradd_pprof:ID() }
app_home.parents = true
app_home.recursion = true
app_home.owner = "www"
app_home.group = "www"

git = resource.git.new("/tmp/graphviz")
git.require = { prepare:ID(), useradd_pprof:ID() }
git.url = "https://gitlab.com/graphviz/graphviz.git"
git.proxy = "http://10.45.7.145:8118"


flame_graph = resource.git.new("/home/www/system/pprof/FlameGraph")
flame_graph.require = { useradd_pprof:ID(), app_home:ID(), git:ID() }
flame_graph.url = "https://github.com/brendangregg/FlameGraph.git"
flame_graph.redirect = true
flame_graph.proxy = "http://10.45.7.145:8118"
flame_graph.owner = "www"
flame_graph.group = "www"


-- pprofFileName = string.format("graphviz-%s.tar.gz", graphviz_version)
-- pprofFilePath = "/tmp/"..pprofFileName
-- remote_pprof = resource.remoteFile.new(pprofFilePath)
-- remote_pprof.require = { prev:ID() }
-- remote_pprof.proxy = proxy
-- remote_pprof.state = "present"
--
-- remote_pprof.url = string.format("https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/%s/graphviz-%s.tar.gz", graphviz_version, graphviz_version)
--
-- dearchive_pprof = resource.archive.new("/tmp")
-- dearchive_pprof.require = { remote_pprof:ID(), prev:ID() }
-- dearchive_pprof.decompress = true
--
-- dearchive_pprof.source = pprofFilePath
--


-- cd ${DOWNLOAD_PATH}/${APP_NAME}/graphviz-2.44.0 && ./configure --prefix=${APP_PATH}/graphviz
-- cd ${DOWNLOAD_PATH}/${APP_NAME}/graphviz-2.44.0 && make && make install
-- cp -R ${DOWNLOAD_PATH}/${APP_NAME}/FlameGraph ${APP_PATH}

make_graphviz_cmd = "cd /tmp/graphviz && ./autogen.sh" .. " && " .. string.format("./configure --prefix=%s/graphviz", app_path) .. " && make && make install"
make_graphviz= resource.shell.new("make_graphviz")
make_graphviz.require = { flame_graph:ID(), useradd_pprof:ID() }
make_graphviz.command = make_graphviz_cmd

app_home2 = resource.directory.new("chown")
app_home2.require = { make_graphviz:ID() }
app_home2.path = app_path
app_home2.recursion = true
app_home2.owner = "www"
app_home2.group = "www"



-- graphviz_file = resource.file.new(string.format("%s/FlameGraph", app_path))
-- graphviz_file.require = { app_home:ID(), make_graphviz:ID(), useradd_pprof:ID() }
-- graphviz_file.source = string.format("/tmp/graphviz-%s/FlameGraph", graphviz_version)
-- graphviz_file.mode = tonumber("0755", 8)
-- graphviz_file.owner = "www"
-- graphviz_file.group = "www"



catalog:add(prepare, git, flame_graph, make_graphviz, groupadd_pprof, useradd_pprof, app_home, app_home2)
