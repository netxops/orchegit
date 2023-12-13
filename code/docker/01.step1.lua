--!/usr/bin/lua
package.path = GetLocalPackagePath(package.path)
require("lib")

function enable_proxy()
  local cmd = [[
  export HTTP_PROXY=http://10.45.7.145:8118
  export HTTPS_PROXY=http://10.45.7.145:8118
  export http_proxy=http://10.45.7.145:8118
  export https_proxy=http://10.45.7.145:8118

  ]]

  ds = resource.shell.new(cmd)
  catalog:add(ds)

  return ds
end

function disable_autoupdate()
  -- 取消安装服务自启动
  ds1 = resource.shell.new("echo -e '#!/bin/sh\nexit 101' | install -m 755 /dev/stdin /usr/sbin/policy-rc.d")

  local cmds = {
    "systemctl mask apt-daily.service apt-daily-upgrade.service",
    "systemctl stop apt-daily.timer apt-daily-upgrade.timer",
    "systemctl disable apt-daily.timer apt-daily-upgrade.timer",
    "systemctl kill --kill-who=all apt-daily.service",

    -- // undo what's in 20auto-upgrade
    "cat > /etc/apt/apt.conf.d/10cloudinit-disable << EOF",
    [[APT::Periodic::Enable "0";]],
    [[APT::Periodic::Update-Package-Lists "0";]],
    [[APT::Periodic::Unattended-Upgrade "0";]],
    [[EOF]]
  }
  local cmds_list = table.concat(cmds, "\n")

  ds2 = resource.shell.new(cmds_list)
  catalog:add(ds1, ds2)

  return ds1
end


function change_history(prev)
  local df = resource.shell.new("echo '1' || true")
  df.mute = true

  local cmds = {
    "cat << EOF >> /etc/bash.bashrc",
    "# history actions record，include action time, user, login ip",
    "HISTFILESIZE=5000",
    "HISTSIZE=5000",
    [[ USER_IP=\$(who -u am i 2>/dev/null | awk '{print \$NF}' | sed -e 's/[()]//g') ]],
    [[ if [ -z \$USER_IP ]  ]],
    "then",
      [[ USER_IP=\$(hostname -i) ]],
    "fi",
    [[ HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S \$USER_IP:\$(whoami) " ]],
    "export HISTFILESIZE HISTSIZE HISTTIMEFORMAT",

    "# PS1",
    [[ PS1='\[\033[0m\]\[\033[1;36m\][\u\[\033[0m\]@\[\033[1;32m\]\h\[\033[0m\] \[\033[1;31m\]\w\[\033[0m\]\[\033[1;36m\]\]\[\033[33;1m\]\\$ \[\033[0m\]' ]],
    "EOF"
  }

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end

function install_docker(prev)
  local df = resource.shell.new("echo '12' || true")
  df.mute = true

  local cmd = [[
apt-get install -y apt-transport-https ca-certificates curl gnupg2 lsb-release bash-completion
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg --proxy 10.45.7.145:8118 | sudo apt-key add -
echo "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker-ce.list
sudo apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
apt-mark hold docker-ce docker-ce-cli containerd.io

cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
mkdir  /etc/docker
cat >> /etc/docker/daemon.json <<EOF
{
  "data-root": "/var/lib/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "200m",
    "max-file": "5"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 655360,
      "Soft": 655360
    },
    "nproc": {
      "Name": "nproc",
      "Hard": 655360,
      "Soft": 655360
    }
  },
  "live-restore": true,
  "oom-score-adjust": -1000,
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://yssx4sxy.mirror.aliyuncs.com/"
  ]
}
EOF

usermod -aG docker jacky
mkdir /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://10.45.7.145:8118"
Environment="HTTPS_PROXY=http://10.45.7.145:8118"
Environment="NO_PROXY=localhost,127.0.*,10.46.*,10.45.*"

EOF

systemctl daemon-reload

systemctl enable --now docker

sed -i 's|#oom_score = 0|oom_score = -999|' /etc/containerd/config.toml
cat << EOF > /etc/crictl.yaml
runtime-endpoint: unix:///var/run/dockershim.sock
image-endpoint: unix:///var/run/dockershim.sock
timeout: 2
debug: false
pull-image-on-create: true
disable-pull-on-run: false
EOF

systemctl enable --now containerd
  ]]

  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end



-- re = repo(df)
--
enable_proxy()
da = disable_autoupdate()
-- cl = change_limit(dss)
-- cs = change_sysctl(cl)
-- ch = change_history(da)
idc = install_docker(da)

