--
-- Gru module for installing and configuring memcached
--

-- run shell command: ls /var/log

ls = resource.shell.new("ls /var")

-- Finally, register the resources to the catalog
catalog:add(ls)
