--!/usr/bin/lua
--
mysql_version = "5.7.29"
boost_version_dir = "1.59.0"
boost_version = "1_59_0"
--
env_commands = {
  string.format("export HTTP_PROXY=http://%s:%s", proxy_ip, proxy_port),
  string.format("export HTTPS_PROXY=http://%s:%s", proxy_ip, proxy_port),
  string.format("export http_proxy=http://%s:%s", proxy_ip, proxy_port),
  string.format("export https_proxy=http://%s:%s", proxy_ip, proxy_port),
}
--

mysql_prepare = resource.phase.new("mysql_prepare")
for _, cmd in ipairs(env_commands) do
  env = resource.shell.new(cmd)
  mysql_prepare:add(env)
end


--------------------------------------------------------------------------------
install_package = resource.phase.new("install_package")
install_package.require = { mysql_prepare:ID()  }
package_list = {"build-essential", "cmake", "bison", "libncurses5-dev", "libncursesw5-dev", "libboost-all-dev", "openssl", "libssl-dev"}
prev = ""
for i, name in ipairs(package_list) do
  p = resource.package.new(name)
  if (prev == "") then
    prev = p
  else
    p.require = { prev:ID() }
    prev = p
  end
  install_package:add(p)
end

--------------------------------------------------------------------------------
build_mysql = resource.phase.new("build_mysql")
build_mysql.require = { install_package:ID() }

mysqlFileName = string.format("mysql-%s.tar.gz", mysql_version)
mysqlFilePath = "/tmp/"..mysqlFileName
remote_mysql = resource.remoteFile.new(mysqlFilePath)
remote_mysql.proxy = "http://10.45.7.145:8118"
remote_mysql.state = "present"
remote_mysql.url = string.format("https://github.com/mysql/mysql-server/archive/mysql-%s.tar.gz", mysql_version)

dearchive_mysql = resource.archive.new("/tmp")
dearchive_mysql.require = { remote_mysql:ID() }
dearchive_mysql.decompress = true
dearchive_mysql.source = mysqlFilePath 


boostFileName = string.format("boost_%s.tar.gz", boost_version)
boostFilePath = "/tmp/"..boostFileName
remote_boost = resource.remoteFile.new(boostFilePath)
remote_boost.require = { remote_mysql:ID() }
remote_boost.proxy = "http://10.45.7.145:8118"
remote_boost.state = "present"
remote_boost.url = string.format("http://sourceforge.net/projects/boost/files/boost/%s/boost_%s.tar.gz", boost_version_dir, boost_version)

dearchive_boost = resource.archive.new("/tmp/boost")
dearchive_boost.require = { remote_boost:ID() }
dearchive_boost.decompress = true
dearchive_boost.source = boostFilePath 


groupadd_mysql = resource.group.new("mysql")
groupadd_mysql.system = true

useradd_mysql = resource.user.new("mysql")
useradd_mysql.require = { groupadd_mysql:ID() }
useradd_mysql.group ="mysql"
useradd_mysql.system = true
useradd_mysql.nologin = true


make_mysql_cmd = string.format("cd /tmp/mysql-server-mysql-%s/", mysql_version) .. " && " .. [[cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
-DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
-DDEFAULT_CHARSET=utf8mb4 \
-DDEFAULT_COLLATION=utf8mb4_general_ci \
-DWITH_EXTRA_CHARSETS=all \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_MEMORY_STORAGE_ENGINE=1 \
-DWITH_BOOST=/tmp/boost/ \
-DWITH_READLINE=1 \
-DENABLED_LOCAL_INFILE=1 \
-DMYSQL_DATADIR=/var/mysql/data \
-DMYSQL_USER=mysql]] .. " && make && make install"




build_mysql:add(remote_mysql, dearchive_mysql, groupadd_mysql, useradd_mysql, remote_boost, dearchive_boost)
--------------------------------------------------------------------------------
install_mysql = resource.phase.new("install_mysql")
install_mysql.require = { build_mysql:ID() }

make_mysql = resource.shell.new("make_mysql")
make_mysql.command = make_mysql_cmd
make_mysql.creates = "/usr/local/mysql/bin/mysql"

mysql_path = resource.appendFile.new("/etc/profile")
mysql_path.require = { make_mysql:ID() }
mysql_path.content = "export PATH=$PATH:/usr/local/mysql/bin"


mysql_directory = resource.directory.new("/usr/local/mysql")
mysql_directory.require = { make_mysql:ID() }
mysql_directory.owner = "mysql"
mysql_directory.group = "mysql"
--
-- mysql_directory_var = resource.shell.new("/usr/local/mysql/var")
-- mysql_directory_var.require = { make_directory:ID() }
-- mysql_directory_var.owner = "mysql"
-- mysql_directory_var.group = "mysql"
--
install_mysql:add(make_mysql, mysql_path, mysql_directory)
----------------------------------------------------------------------------------------
mysql_working = resource.phase.new("mysql_working")
mysql_working.require = { install_mysql:ID() }

mysql_client_lib = resource.link.new("/usr/lib/libmysqlclient.so.20")
mysql_client_lib.source = "/usr/local/mysql/lib/libmysqlclient.so.20"

mysql_working:add(mysql_client_lib)

mysql_dir_list = {
  "/var/mysql/",
  "/var/mysql/data/",
  "/var/mysql/log/"
}

prev = ""
for i, name in ipairs(mysql_dir_list) do
  p = resource.directory.new(name)
  p.owner = "mysql"
  p.group = "mysql"
  if prev == "" then
    prev = p
  else
    p.require = { prev:ID() }
    prev = p
  end
  mysql_working:add(p)
end

mysql_config_file = resource.file.new("/var/mysql/my.cnf")
mysql_config_file.source = "site/data/mysql/my.cnf"

-- mysql_service_dir = resource.directory.new("/etc/rc.d/init.d/")
-- mysql_service_dir.parents = true

mysql_install_db_cmd = [[/usr/local/mysql/bin/mysqld \
--initialize \
--basedir=/usr/local/mysql \
--datadir=/var/mysql/data \
--user=mysql]]
--A temporary password is generated for root@localhost: LEG25(LxYOFb
mysql_install_db = resource.shell.new("mysql_install_db")
mysql_install_db.require = { prev:ID() }
mysql_install_db.command = mysql_install_db_cmd 
mysql_install_db.creates = "/var/mysql/data/ibdata1"


-- mysql_chmod_x = resource.shell.new("chmod +x /etc/init.d/mysqld")
-- mysql_chmod_x.require = { mysql_install_db:ID() }

-- mysql_initd_mysqld = resource.file.new("/etc/init.d/mysqld")
-- mysql_initd_mysqld.require = { mysql_chmod_x:ID() }
-- mysql_initd_mysqld.content = [[basedir=/usr/local/mysql
-- datadir=/var/mysql/data]]
--
--
--
mysql_service = resource.file.new("/etc/init.d/mysqld")
mysql_service.require = { mysql_install_db:ID() }
mysql_service.source = string.format("/tmp/mysql-server-mysql-%s/", mysql_version) .. "/support-files/mysql.server"

mysql_chmod_x = resource.shell.new("chmod +x /etc/init.d/mysqld")
mysql_chmod_x.require = { mysql_service:ID() }


mysql_update_rcd = resource.shell.new("update-rc.d mysqld defaults")
mysql_update_rcd.creates = "/etc/rc0.d/K01mysqld"
mysql_update_rcd.require = { mysql_chmod_x:ID() }

mysql_working:add(mysql_config_file, mysql_install_db)
mysql_working:add(mysql_service, mysql_chmod_x, mysql_update_rcd)




catalog:add(mysql_prepare, install_package, build_mysql, install_mysql, mysql_working)
