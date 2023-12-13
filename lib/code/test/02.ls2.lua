ips = factor.ip()
ip = string.sub(ips, string.find(ips, "10.46.%d+.%d+"))
print("ip: ", ip)
print("-------------------------------------------")

phase = resource.phase.new("phase1")

ls2 = resource.shell.new("echo 'hello'")
-- ls2.require = {
    -- ls:ID()
-- }

sv1 = resource.shell.new([[curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4]])
sv1.require = { ls2:ID() }

sv2 = resource.shell.new("echo 1")
sv2.require = { sv1:ID() }


sv3 = resource.shell.new([[curl  -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4]])
sv3.require = { sv2:ID() }


--
sv2.subscribe[sv1:ID()] = function()
  print(sv1.output)
  print("this is from trigger.")
end

phase:add(ls2, sv1, sv2, sv3)
-- print(GetLocalPackagePath(package.path))
-- print(string.find(GetLocalPackagePath(), GetLuaPath()))

-- Finally, register the resources to the catalog
--

function fprint (...)
  printResult = ""
  for i,v in ipairs(arg) do
    printResult = printResult .. tostring(v) .. "\t"
  end
  printResult = printResult .. "\n"
  return  printResult
end

print("-------------------------------------------------====")
print(fprint("1", "2", "3"))

--
-- group = resource.group.new("netops")
-- group.system = true
-- group.require = { phase:ID() }

-- user = resource.user.new("netops")
-- user.require = { group:ID() }
-- user.group = "netops"
-- user.system = true
-- user.home = "/home/netops"
-- user.password = "cisco123"

--


-- catalog:add(phase, group, user)
catalog:add(phase)

base = resource.base.new("test_data")
base.require = { phase:ID() }
base.file = "site/data/etcd/etcd_default.conf"
d = {}
d.ETCD_NAME = factor.fqdn()
d.ETCD_HOST_IP = ip
d.Nodes = {"etcd1", "etcd2", "etcd3"}
base.data = d
-- base.data.foo = "123"
-- base.data.bar = "456"
-- base.data.baz = false

catalog:add(base)
