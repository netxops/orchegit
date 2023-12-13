--!/usr/bin/lua
prometheus_version = "2.19.2"
proxy = "http://10.45.7.145:8118"
sample_config = "/home/jacky/juno/config/juno-prometheus.yml"
--------------------------------------------------------------------------------

prometheusFileName = string.format("prometheus-%s.tar.gz", prometheus_version)
prometheusFilePath = "/tmp/"..prometheusFileName
remote_prometheus = resource.remoteFile.new(prometheusFilePath)
remote_prometheus.proxy = proxy
remote_prometheus.state = "present"
remote_prometheus.url = string.format("https://github.com/prometheus/prometheus/releases/download/v%s/prometheus-%s.linux-amd64.tar.gz", prometheus_version, prometheus_version)

dearchive_prometheus = resource.archive.new("/tmp")
dearchive_prometheus.require = { remote_prometheus:ID() }
dearchive_prometheus.decompress = true
dearchive_prometheus.source = prometheusFilePath 

groupadd_prometheus = resource.group.new("www")
groupadd_prometheus.system = true

useradd_prometheus = resource.user.new("www")
useradd_prometheus.require = { groupadd_prometheus:ID() }
useradd_prometheus.group ="www"
useradd_prometheus.system = true
useradd_prometheus.nologin = true
useradd_prometheus.home = "/home/www"

directory = resource.directory.new("/home/www/system/prometheus/")
directory.require = { useradd_prometheus:ID() }
directory.parents = true
directory.owner = "www"
directory.group = "www"

config_directory = resource.directory.new("/home/www/system/prometheus/conf")
config_directory.require = { useradd_prometheus:ID() }
config_directory.parents = true
config_directory.owner = "www"
config_directory.group = "www"

data_directory = resource.directory.new("/home/www/system/prometheus/data")
data_directory.require = { useradd_prometheus:ID() }
data_directory.parents = true
data_directory.owner = "www"
data_directory.group = "www"


copyFile = resource.copy.new("/home/www/system/prometheus/")
copyFile.require = { data_directory:ID(), config_directory:ID(), useradd_prometheus:ID(), dearchive_prometheus:ID(), directory:ID() }
copyFile.source = { string.format("/tmp/prometheus-%s.linux-amd64/", prometheus_version) }
copyFile.owner = "www"
copyFile.group = "www"

config_file = resource.file.new("/home/www/system/prometheus/juno-prometheus.yml")
config_file.require = { copyFile:ID() }
config_file.source = sample_config
config_file.owner = "www" 
config_file.group = "www"


unit_file = resource.file.new("/etc/systemd/system/juno-prometheus.service")
unit_file.require = { config_file:ID() }
unit_file.source = "site/data/prometheus/default.conf"

systemd_deamon = resource.shell.new("systemctl daemon-reload")
systemd_deamon.require = { unit_file:ID() }

svc = resource.service.new("juno-prometheus")
svc.require = { systemd_deamon:ID() }
svc.state = "running"
svc.enable = true
svc.require = { systemd_deamon:ID() }


catalog:add(remote_prometheus, dearchive_prometheus, groupadd_prometheus, useradd_prometheus, directory,data_directory, config_directory, copyFile, config_file, unit_file, systemd_deamon, svc)
