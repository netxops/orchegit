--
-- Gru module for installing and configuring memcached
--

-- run shell command: apt-get upgrade -y

system_upgrade = resource.shell.new("apt-get upgrade -y")

-- Finally, register the resources to the catalog
catalog:add(system_upgrade)
