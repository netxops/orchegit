--
-- Gru module for installing and configuring memcached
--

-- run shell command: ls /etc

ls = resource.shell.new("ls /etc")


systemd_dir = "/home/jacky/"
-- Test C
unit_file = resource.file.new(systemd_dir .. "override.conf")
unit_file.state = "present"
unit_file.mode = tonumber("0644", 8)
unit_file.source = "data/memcached/memcached-override.conf"


-- Finally, register the resources to the catalog
catalog:add(ls, unit_file)
