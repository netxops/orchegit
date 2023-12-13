--
-- Gru module for installing and configuring memcached
--

-- 停止服务
svc = resource.service.new("memcached")
svc.state = "absent"
svc.enable = false

-- Path to the systemd drop-in unit directory
systemd_dir = "/etc/systemd/system/memcached.service.d/"

-- 删除systemd drop in文件 
unit_file = resource.file.new(systemd_dir .. "override.conf")
unit_file.state = "absent"
unit_file.require = {
   svc:ID(),
}

-- 删除package 
pkg = resource.package.new("memcached")
pkg.state = "absent"

pkg.require = {
   svc:ID(),
}

-- 重启加载systemd
systemd_reload = resource.shell.new("systemctl daemon-reload")
systemd_reload.require = {
   pkg:ID(),
}


-- 结束，将resource注册到catalog
catalog:add(pkg, unit_dir, unit_file, systemd_reload, svc)
