--
-- Gru module for installing and configuring memcached
--
-- Instruct systemd(1) to reload it's configuration
--
package.path = GetLocalPackagePath(package.path)
-- print(package.path)
-- print(GetLocalPackagePath(package.path))

ls = resource.shell.new("echo 'this is 1'")

require("lib")

print(utils.file_exists("/home/jacky/1.txt"))
-- print(GetLocalPackagePath(package.path))
-- print(string.find(GetLocalPackagePath(), GetLuaPath()))

-- Finally, register the resources to the catalog
catalog:add(ls)
