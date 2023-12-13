--!/usr/bin/lua
--
tmp_file = resource.file.new("/tmp/appendTest.conf")
tmp_file.state = "present"
tmp_file.mode = tonumber("0644", 8)
tmp_file.source = "site/data/memcached/memcached-override.conf"


append_file = resource.appendFile.new("/tmp/appendTest.conf")
append_file.require = { tmp_file:ID() }
append_file.state = "installed"
append_file.force = true
append_file.content = "this is append line."
append_file.mode = tonumber("0644", 8)

phase1 = resource.phase.new("phase1")
phase1.require = { append_file:ID() }

deappend_file = resource.appendFile.new("/tmp/appendTest.conf")
deappend_file.state = "present"
deappend_file.force = true
deappend_file.content = "this is append line."
deappend_file.mode = tonumber("0644", 8)
phase1:add(deappend_file)

catalog:add(tmp_file, append_file, phase1)
