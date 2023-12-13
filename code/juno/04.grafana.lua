--!/usr/bin/lua
--!/usr/bin/lua
grafana_version = "7.0.5"
proxy = "http://10.45.7.145:8118"
sample_config = "/home/jacky/juno/config/juno-grafana.ini"
db_user = "root"
db_pass = "root123"
db_host = "127.0.0.1"
db_port = "3306"
db_name = "grafana"

host_port = "3001"
--------------------------------------------------------------------------------

grafanaFileName = string.format("grafana-%s.tar.gz", grafana_version)
grafanaFilePath = "/tmp/"..grafanaFileName
remote_grafana = resource.remoteFile.new(grafanaFilePath)
remote_grafana.proxy = proxy
remote_grafana.state = "present"
remote_grafana.url = string.format("https://dl.grafana.com/oss/release/grafana-%s.linux-amd64.tar.gz", grafana_version, grafana_version)

dearchive_grafana = resource.archive.new("/tmp")
dearchive_grafana.require = { remote_grafana:ID() }
dearchive_grafana.decompress = true
dearchive_grafana.source = grafanaFilePath 

groupadd_grafana = resource.group.new("www")
groupadd_grafana.system = true

useradd_grafana = resource.user.new("www")
useradd_grafana.require = { groupadd_grafana:ID() }
useradd_grafana.group ="www"
useradd_grafana.system = true
useradd_grafana.nologin = true
useradd_grafana.home = "/home/www"

server_directory = resource.directory.new("/home/www/server")
server_directory.require = { useradd_grafana:ID() }
server_directory.mode = tonumber("0775", 8)
server_directory.owner = "www"
server_directory.group = "www"

directory = resource.directory.new("/home/www/server/grafana/")
directory.require = { server_directory:ID() }
directory.parents = true
directory.mode = tonumber("0775", 8)
directory.owner = "www"
directory.group = "www"

copy_file = resource.copy.new("/home/www/server/grafana/")
copy_file.require = {  useradd_grafana:ID(), dearchive_grafana:ID(), directory:ID() }
copy_file.source = { string.format("/tmp/grafana-%s/", grafana_version) }
copy_file.owner = "www"
copy_file.group = "www"

config_dir = resource.directory.new("/home/www/server/grafana")
config_dir.require = { copy_file:ID() }
config_dir.parents = true
config_dir.recursion = true
config_dir.mode = tonumber("0755", 8)
config_dir.owner = "www"
config_dir.group = "www"

bin_dir = resource.directory.new("/home/www/server/grafana/bin")
bin_dir.require = { config_dir:ID() }
bin_dir.parents = true
bin_dir.recursion = true
bin_dir.mode = tonumber("0775", 8)
bin_dir.owner = "www"
bin_dir.group = "www"


workhome_dir = resource.directory.new("change workhome dir mode")
workhome_dir.require = { config_dir:ID() }
workhome_dir.mode = tonumber("0775", 8)
bin_dir.recursion = true
workhome_dir.owner = "www"
workhome_dir.group = "www"
workhome_dir.path = "/home/www/server/grafana"


config_file = resource.file.new("/home/www/server/grafana/conf/juno-grafana.ini")
config_file.require = { bin_dir:ID(), workhome_dir:ID() }
config_file.source = "site/data/grafana/juno-grafana.ini"
config_file.mode = tonumber("0755", 8)
config_file.owner = "www" 
config_file.group = "www"
d = {}
d.db_user = db_user
d.db_pass = db_pass
d.db_host = db_host
d.db_port = db_port
d.db_name = db_name

d.host_port = host_port
config_file.data = d


unit_file = resource.file.new("/etc/systemd/system/juno-grafana.service")
unit_file.require = { bin_dir:ID() }
unit_file.source = "site/data/grafana/default.conf"

systemd_deamon = resource.shell.new("systemctl daemon-reload")
systemd_deamon.require = { unit_file:ID() }

svc = resource.service.new("juno-grafana")
svc.require = { systemd_deamon:ID() }
svc.state = "running"
svc.enable = true
svc.require = { systemd_deamon:ID() }


catalog:add(remote_grafana, dearchive_grafana, groupadd_grafana, useradd_grafana, server_directory, directory, config_dir, bin_dir, workhome_dir, copy_file, config_file, unit_file, systemd_deamon, svc)
