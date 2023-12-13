--!/usr/bin/lua
--
-- Gru module for installing and configuring memcached
--

-- run shell command: ls /etc
phase = resource.phase.new("phase1")

ls = resource.shell.new("ls /etc")

phase:add(ls)


-- Finally, register the resources to the catalog
catalog:add(phase)
