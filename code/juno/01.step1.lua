--!/usr/bin/lua
package.path = GetLocalPackagePath(package.path)
require("lib")

proxy_ip = "10.45.7.145"
proxy_port = "8118"
network_filter = "10.46.%d+.%d+"
etcd_version = "v3.5.2"
node_list = {"etcd1", "etcd2", "etcd3"}

ips = factor.ip()
ip = string.sub(ips, string.find(ips, network_filter))

-- env_commands = {
  -- string.format("export HTTP_PROXY=http://%s:%s", proxy_ip, proxy_port),
  -- string.format("export HTTPS_PROXY=http://%s:%s", proxy_ip, proxy_port),
  -- string.format("export http_proxy=http://%s:%s", proxy_ip, proxy_port),
  -- string.format("export https_proxy=http://%s:%s", proxy_ip, proxy_port),
-- }

prepare_env = resource.phase.new("prepare_env")
--
-- for _, cmd in ipairs(env_commands) do
  -- env = resource.shell.new(cmd)
  -- prepare_env:add(env)
-- end
hosts = resource.hosts.new("/etc/hosts")
hosts.state = "present"
hosts.map.etcd1 = "10.46.9.27"
hosts.map.etcd2 = "10.46.9.28"
hosts.map.etcd3 = "10.46.9.29"


multipath = resource.appendFile.new("/etc/multipath.conf")
multipath.content = [[
blacklist {
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st|sda)[0-9]*"
}
]]




prepare_env:add(hosts, multipath)


prepare_pkg = resource.phase.new("prepare_pkg") 
prepare_pkg.require = { prepare_env:ID() }

wget = resource.package.new("wget")
wget.state = "present"

curl = resource.package.new("curl")
curl.state = "present"
curl.require = { wget:ID() }
prepare_pkg:add(wget, curl)


install_etcd = resource.phase.new("install_etcd")
install_etcd.require = { prepare_pkg:ID() }

etcdFileName = string.format("etcd-%s-linux-amd64.tar.gz", etcd_version)
etcdFilePath = "/tmp/"..etcdFileName
remoteFile = resource.remoteFile.new(etcdFilePath)
remoteFile.proxy = "http://10.45.7.145:8118"
remoteFile.state = "present"
remoteFile.url = string.format("https://github.com/etcd-io/etcd/releases/download/%s/%s", etcd_version, etcdFileName)
--
-- archive = resource.archive.new("a.zip")
-- archive.require = { remoteFile:ID() }
-- archive.source = "site_bak/code"

dearchive = resource.archive.new("/tmp")
dearchive.require = { remoteFile:ID() }
dearchive.decompress = true
dearchive.source = etcdFilePath 
--
copyFile = resource.copy.new("/usr/local/bin")
copyFile.require = { dearchive:ID() }
copyFile.source = { string.format("/tmp/etcd-%s-linux-amd64/etcd", etcd_version), string.format("/tmp/etcd-%s-linux-amd64/etcdctl", etcd_version) }

install_etcd:add(remoteFile, dearchive, copyFile)

---------------------------------------------------

etcd_service = resource.phase.new("config etcd service")
etcd_service.require = { install_etcd:ID() }
--
--
groupadd = resource.group.new("etcd")
groupadd.system = true

useradd = resource.user.new("etcd")
useradd.require = { groupadd:ID() }
useradd.group ="etcd"
useradd.system = true
useradd.nologin = true

mkdir2 = resource.directory.new("/etc/etcd")

chown = resource.directory.new("/var/lib/etcd/")
chown.require = { useradd:ID() }
chown.owner = "etcd"
chown.group = "etcd"
-- chown = resource.shell.new("chown -R etcd:etcd /var/lib/etcd/")
-- chown.require = { mkdir1:ID(), mkdir2:ID(), groupadd:ID(), useradd:ID() }
-- chown.require = { mkdir1:ID(), mkdir2:ID() }

systemd_dir = "/etc/systemd/system/etcd.service"
-- unit_dir = resource.directory.new(systemd_dir)
-- unit_dir.state = "present"

unit_file = resource.file.new(systemd_dir)
unit_file.require = { chown:ID() }
unit_file.state = "present"
unit_file.mode = tonumber("0644", 8)
unit_file.source = "site/data/etcd/etcd_default.conf"
d = {}

d.EtcdName = factor.fqdn()
d.EtcdHostIP = ip
d.Nodes = node_list
unit_file.data = d

systemd_deamon = resource.shell.new("systemctl daemon-reload")
systemd_deamon.require = { unit_file:ID() }
-- systemd_start = resource.shell.new("systemctl start etcd.service")
-- systemd_start.require = { systemd_deamon:ID() }

svc = resource.service.new("etcd")
svc.state = "running"
svc.enable = true
svc.require = { systemd_deamon:ID() }


reload_multipath = resource.shell.new("systemctl restart multipathd.service")
reload_multipath.require = { systemd_deamon:ID() }


-- etcd_service:add(mkdir1, mkdir2, groupadd, useradd, chown, unit_dir, unit_file, systemd_deamon, systemd_start)
-- etcd_service:add( unit_file, systemd_deamon, systemd_start)
etcd_service:add(mkdir2, groupadd, useradd, chown, unit_file, systemd_deamon, svc, reload_multipath)

catalog:add(prepare_env, install_etcd, etcd_service)
