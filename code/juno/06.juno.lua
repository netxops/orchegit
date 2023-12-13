--!/usr/bin/lua
juno_version = "0.4.14"
proxy = "http://10.45.7.145:8118"
sample_config = "/home/jacky/juno/config/juno-juno.yml"
db_user = "root"
db_pass = "root123"
db_host = "127.0.0.1"
db_port = "3306"
db_name = "grafana"

--------------------------------------------------------------------------------
--
git = resource.git.new("/tmp/juno")
git.url = "https://github.com/douyu/juno.git"
git.proxy = "http://10.45.7.145:8118"

junoFileName = string.format("juno_%s_linux_amd64.tar.gz", juno_version)
junoFilePath = "/tmp/"..junoFileName
remote_juno = resource.remoteFile.new(junoFilePath)
remote_juno.require = { git:ID() }
remote_juno.proxy = proxy
remote_juno.state = "present"
remote_juno.url = string.format("https://github.com/douyu/juno/releases/download/v%s/juno_%s_linux_amd64.tar.gz", juno_version, juno_version)

dearchive_juno = resource.archive.new("/tmp/juno_bin")
dearchive_juno.require = { remote_juno:ID() }
dearchive_juno.decompress = true
dearchive_juno.source = junoFilePath 

groupadd_juno = resource.group.new("www")
groupadd_juno.system = true

useradd_juno = resource.user.new("www")
useradd_juno.require = { groupadd_juno:ID() }
useradd_juno.group ="www"
useradd_juno.system = true
useradd_juno.nologin = true
useradd_juno.home = "/home/www"

directory = resource.directory.new("/home/www/server/juno/config")
directory.require = { useradd_juno:ID() }
directory.parents = true
directory.owner = "www"
directory.group = "www"

directory2 = resource.directory.new("/home/www/server/juno/data")
directory2.require = { useradd_juno:ID() }
directory2.parents = true
directory2.owner = "www"
directory2.group = "www"

d = {}
d.db_user = db_user
d.db_pass = db_pass
d.db_host = db_host
d.db_port = db_port
d.db_name = db_name
d.host_port = host_port

install_file = resource.file.new("/home/www/server/juno/config/install.toml")
install_file.source = "site/data/juno/install.toml"
install_file.require = { directory:ID() }
install_file.data = d

single_file = resource.file.new("/home/www/server/juno/config/single-region-admin.toml")
single_file.source = "site/data/juno/single-region-admin.toml"
single_file.require = { directory:ID() }
single_file.data = d

multiple_file = resource.file.new("/home/www/server/juno/config/multiple-region-admin.toml")
multiple_file.source = "site/data/juno/multiple-region-admin.toml"
multiple_file.require = { directory:ID() }
multiple_file.data = d


data_files = resource.copy.new("/home/www/server/juno/data")
data_files.require = { directory2:ID() }
data_files.source = { "/tmp/juno/data" }


chown = resource.directory.new("chown")
chown.path = "/home/www/server/juno/"
chown.require = { data_files:ID(), install_file:ID(), single_file:ID(), multiple_file:ID() }
chown.parents = true
chown.recursion = true
chown.owner = "www"
chown.group = "www"

catalog:add(git, remote_juno, dearchive_juno, groupadd_juno, useradd_juno, directory, directory2, chown, install_file, single_file, multiple_file, data_files)
