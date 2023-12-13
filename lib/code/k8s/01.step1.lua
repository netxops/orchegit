--!/usr/bin/lua
package.path = GetLocalPackagePath(package.path)
require("lib")


init_node = {
  clean_cmd = {
    "sed -i -e '/" .. KUBE_APISERVER .. "/d' -e '/-worker-/d' -e '/-master-/d' /etc/hosts",
    "sed -i '/## Kainstall managed start/,/## Kainstall managed end/d' /etc/security/limits.conf /etc/systemd/system.conf ~/.bashrc /etc/audit/rules.d/audit.rules"
  },
  disable_selinux = {
    "sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config",
    "setenforce 0"
  },
  disable_swap = {
    "swapoff -a && sysctl -w vm.swappiness=0",
    "sed -ri '/^[^#]*swap/s@^@#@' /etc/fs"
  },
  disable_firewall = {
    "firewalld", "iptables", "ufw"
  },
  codename = utils.ubuntu_codename()
}


function disable_firewall()
  local df = resource.shell.new("echo '1' || true")
  df.mute = true

  for _, v in ipairs(init_node.disable_firewall) do
    ds1 = resource.shell.new("systemctl stop " .. v .. " &>/dev/null || true")
    catalog:add(ds1)
    df:pushRequire(ds1:ID())

    ds2 = resource.shell.new("systemctl disable " .. v .. " &>/dev/null || true")
    ds2.require = {ds1:ID()}
    df:pushRequire(ds2:ID())
    catalog:add(ds2)
  end

  catalog:add(df)
  return df
end


function repo(prev)
  local df = resource.shell.new("echo '2' || true")
  df.mute = true

  if not SKIP_SET_OS_REPO
  then
    local lines = utils.ubuntu_repo("http://mirrors.aliyun.com/ubuntu/")
    local cmds = {}
    cmds[1] = "cat << EOF > /etc/apt/sources.list"
    for _, line in ipairs(lines) do
      cmds[#cmds+1] = line
    end
    cmds[#cmds+1]= "EOF"
    local cat_repo_list = table.concat(cmds, "\n")

    ds1 = resource.shell.new("cp -fv /etc/apt/sources.list{,.bak}")
    ds1.require = {prev:ID()}
    df:pushRequire(ds1:ID())

    ds2 = resource.shell.new(cat_repo_list)
    ds2.require = {ds1:ID(), prev:ID()}
    df:pushRequire(ds2:ID())

    update = resource.shell.new("apt update")
    update.require = {prev:ID(), ds1:ID(), ds2:ID()}
    df:pushRequire(update:ID())

    catalog:add(ds1, ds2, update, df)
  else
    update = resource.shell.new("apt update")
    update.require = {prev:ID()}

    df:pushRequire(update:ID())
    catalog:add(update, df)
  end
  return df
end

function disable_autoupdate(prev)
  local df = resource.shell.new("echo '3' || true")
  df.mute = true

  -- 取消安装服务自启动
  ds1 = resource.shell.new("echo -e '#!/bin/sh\nexit 101' | install -m 755 /dev/stdin /usr/sbin/policy-rc.d")
  ds1.require = {prev:ID()}
  df:pushRequire(ds1:ID())

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
  ds2.require = {prev:ID()}
  df:pushRequire(ds2:ID())
  catalog:add(ds1, ds2, df)

  return df
end


function disable_selinux_swap(prev) 
  local df = resource.shell.new("echo '4' || true")
  df.mute = true
  local cmds = {
    "setenforce 0",
    [[sed -i "s#=enforcing#=disabled#g" /etc/selinux/config]],
    "swapoff -a && sysctl -w vm.swappiness=0",
    "sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab",
  } 

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end

function change_limit(prev)
  local df = resource.shell.new("echo '5' || true")
  df.mute = true

  local cmds = {
    "[ ! -f /etc/security/limits.conf_bak ] && cp /etc/security/limits.conf{,_bak}",
    "cat << EOF >> /etc/security/limits.conf",
    "root soft nofile 655360",
    "root hard nofile 655360",
    "root soft nproc 655360",
    "root hard nproc 655360",
    "root soft core unlimited",
    "root hard core unlimited",

    "* soft nofile 655360",
    "* hard nofile 655360",
    "* soft nproc 655360",
    "* hard nproc 655360",
    "* soft core unlimited",
    "* hard core unlimited",
    "EOF",

    "[ ! -f /etc/systemd/system.conf_bak ] && cp /etc/systemd/system.conf.conf{,_bak}",
    "cat << EOF >> /etc/systemd/system.conf",
    "DefaultLimitCORE=infinity",
    "DefaultLimitNOFILE=655360",
    "DefaultLimitNPROC=655360",
    "EOF"
  }

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end


function change_sysctl(prev)
  local df = resource.shell.new("echo '6' || true")
  df.mute = true
  local cmd = [[

cat << EOF >  /etc/sysctl.d/99-kube.conf
# https://www.kernel.org/doc/Documentation/sysctl/
#############################################################################################
# 调整虚拟内存
#############################################################################################

# Default: 30
# 0 - 任何情况下都不使用swap。
# 1 - 除非内存不足（OOM），否则不使用swap。
vm.swappiness = 0

# 内存分配策略
#0 - 表示内核将检查是否有足够的可用内存供应用进程使用；如果有足够的可用内存，内存申请允许；否则，内存申请失败，并把错误返回给应用进程。
#1 - 表示内核允许分配所有的物理内存，而不管当前的内存状态如何。
#2 - 表示内核允许分配超过所有物理内存和交换空间总和的内存
vm.overcommit_memory=1

# OOM时处理
# 1关闭，等于0时，表示当内存耗尽时，内核会触发OOM killer杀掉最耗内存的进程。
vm.panic_on_oom=0

# vm.dirty_background_ratio 用于调整内核如何处理必须刷新到磁盘的脏页。
# Default value is 10.
# 该值是系统内存总量的百分比，在许多情况下将此值设置为5是合适的。
# 此设置不应设置为零。
vm.dirty_background_ratio = 5

# 内核强制同步操作将其刷新到磁盘之前允许的脏页总数
# 也可以通过更改 vm.dirty_ratio 的值（将其增加到默认值30以上（也占系统内存的百分比））来增加
# 推荐 vm.dirty_ratio 的值在60到80之间。
vm.dirty_ratio = 60

# vm.max_map_count 计算当前的内存映射文件数。
# mmap 限制（vm.max_map_count）的最小值是打开文件的ulimit数量（cat /proc/sys/fs/file-max）。
# 每128KB系统内存 map_count应该大约为1。 因此，在32GB系统上，max_map_count为262144。
# Default: 65530
vm.max_map_count = 2097152

#############################################################################################
# 调整文件
#############################################################################################

fs.may_detach_mounts = 1

# 增加文件句柄和inode缓存的大小，并限制核心转储。
fs.file-max = 2097152
fs.nr_open = 2097152
fs.suid_dumpable = 0

# 文件监控
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
fs.inotify.max_queued_events=16384

#############################################################################################
# 调整网络设置
#############################################################################################

# 为每个套接字的发送和接收缓冲区分配的默认内存量。
net.core.wmem_default = 25165824
net.core.rmem_default = 25165824

# 为每个套接字的发送和接收缓冲区分配的最大内存量。
net.core.wmem_max = 25165824
net.core.rmem_max = 25165824

# 除了套接字设置外，发送和接收缓冲区的大小
# 必须使用net.ipv4.tcp_wmem和net.ipv4.tcp_rmem参数分别设置TCP套接字。
# 使用三个以空格分隔的整数设置这些整数，分别指定最小，默认和最大大小。
# 最大大小不能大于使用net.core.wmem_max和net.core.rmem_max为所有套接字指定的值。
# 合理的设置是最小4KiB，默认64KiB和最大2MiB缓冲区。
net.ipv4.tcp_wmem = 20480 12582912 25165824
net.ipv4.tcp_rmem = 20480 12582912 25165824

# 增加最大可分配的总缓冲区空间
# 以页为单位（4096字节）进行度量
net.ipv4.tcp_mem = 65536 25165824 262144
net.ipv4.udp_mem = 65536 25165824 262144

# 为每个套接字的发送和接收缓冲区分配的最小内存量。
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_rmem_min = 16384

# 启用TCP窗口缩放，客户端可以更有效地传输数据，并允许在代理方缓冲该数据。
net.ipv4.tcp_window_scaling = 1

# 提高同时接受连接数。
net.ipv4.tcp_max_syn_backlog = 10240

# 将net.core.netdev_max_backlog的值增加到大于默认值1000
# 可以帮助突发网络流量，特别是在使用数千兆位网络连接速度时，
# 通过允许更多的数据包排队等待内核处理它们。
net.core.netdev_max_backlog = 65536

# 增加选项内存缓冲区的最大数量
net.core.optmem_max = 25165824

# 被动TCP连接的SYNACK次数。
net.ipv4.tcp_synack_retries = 2

# 允许的本地端口范围。
net.ipv4.ip_local_port_range = 2048 65535

# 防止TCP时间等待
# Default: net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_rfc1337 = 1

# 减少tcp_fin_timeout连接的时间默认值
net.ipv4.tcp_fin_timeout = 15

# 积压套接字的最大数量。
# Default is 128.
net.core.somaxconn = 32768

# 打开syncookies以进行SYN洪水攻击保护。
net.ipv4.tcp_syncookies = 1

# 避免Smurf攻击
# 发送伪装的ICMP数据包，目的地址设为某个网络的广播地址，源地址设为要攻击的目的主机，
# 使所有收到此ICMP数据包的主机都将对目的主机发出一个回应，使被攻击主机在某一段时间内收到成千上万的数据包
net.ipv4.icmp_echo_ignore_broadcasts = 1

# 为icmp错误消息打开保护
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 启用自动缩放窗口。
# 如果延迟证明合理，这将允许TCP缓冲区超过其通常的最大值64K。
net.ipv4.tcp_window_scaling = 1

# 打开并记录欺骗，源路由和重定向数据包
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# 告诉内核有多少个未附加的TCP套接字维护用户文件句柄。 万一超过这个数字，
# 孤立的连接会立即重置，并显示警告。
# Default: net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_max_orphans = 65536

# 不要在关闭连接时缓存指标
net.ipv4.tcp_no_metrics_save = 1

# 启用RFC1323中定义的时间戳记：
# Default: net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_timestamps = 1

# 启用选择确认。
# Default: net.ipv4.tcp_sack = 1
net.ipv4.tcp_sack = 1

# 增加 tcp-time-wait 存储桶池大小，以防止简单的DOS攻击。
# net.ipv4.tcp_tw_recycle 已从Linux 4.12中删除。请改用net.ipv4.tcp_tw_reuse。
net.ipv4.tcp_max_tw_buckets = 14400
net.ipv4.tcp_tw_reuse = 1

# accept_source_route 选项使网络接口接受设置了严格源路由（SSR）或松散源路由（LSR）选项的数据包。
# 以下设置将丢弃设置了SSR或LSR选项的数据包。
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# 打开反向路径过滤
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# 禁用ICMP重定向接受
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# 禁止发送所有IPv4 ICMP重定向数据包。
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 开启IP转发.
net.ipv4.ip_forward = 1

# 禁止IPv6
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# 要求iptables不对bridge的数据进行处理
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1

# arp缓存
# 存在于 ARP 高速缓存中的最少层数，如果少于这个数，垃圾收集器将不会运行。缺省值是 128
net.ipv4.neigh.default.gc_thresh1=2048
# 保存在 ARP 高速缓存中的最多的记录软限制。垃圾收集器在开始收集前，允许记录数超过这个数字 5 秒。缺省值是 512
net.ipv4.neigh.default.gc_thresh2=4096
# 保存在 ARP 高速缓存中的最多记录的硬限制，一旦高速缓存中的数目高于此，垃圾收集器将马上运行。缺省值是 1024
net.ipv4.neigh.default.gc_thresh3=8192

# 持久连接
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10

# conntrack表
net.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_buckets=262144
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=30
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
net.netfilter.nf_conntrack_tcp_timeout_close_wait=15
net.netfilter.nf_conntrack_tcp_timeout_established=300

#############################################################################################
# 调整内核参数
#############################################################################################

# 地址空间布局随机化（ASLR）是一种用于操作系统的内存保护过程，可防止缓冲区溢出攻击。
# 这有助于确保与系统上正在运行的进程相关联的内存地址不可预测，
# 因此，与这些流程相关的缺陷或漏洞将更加难以利用。
# Accepted values: 0 = 关闭, 1 = 保守随机化, 2 = 完全随机化
kernel.randomize_va_space = 2

# 调高 PID 数量
kernel.pid_max = 65536
kernel.threads-max=30938

# coredump
kernel.core_pattern=core

# 决定了检测到soft lockup时是否自动panic，缺省值是0
kernel.softlockup_all_cpu_backtrace=1
kernel.softlockup_panic=1
EOF

sysctl --system
  ]]

  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end


function change_history(prev)
  local df = resource.shell.new("echo '7' || true")
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

function change_journal(prev)
  local df = resource.shell.new("echo '7' || true")
  df.mute = true

  local cmd = [[
  mkdir -p /var/log/journal /etc/systemd/journald.conf.d
cat << EOF > /etc/systemd/journald.conf.d/99-prophet.conf
[Journal]
# 持久化保存到磁盘
Storage=persistent
# 压缩历史日志
Compress=yes
SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000
# 最大占用空间 10G
SystemMaxUse=10G
# 单日志文件最大 200M
SystemMaxFileSize=200M
# 日志保存时间 3 周
MaxRetentionSec=3week
# 不将日志转发到 syslog
ForwardToSyslog=no
EOF
  ]]

  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end


function change_ssh_login_info(prev)
  local df = resource.shell.new("echo '7' || true")
  df.mute = true

  local cmds = {[[
cat << EOF > /etc/profile.d/zz-ssh-login-info.sh
#!/bin/sh
#
# @Time    : 2020-02-04
# @Author  : lework
# @Desc    : ssh login banner

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
shopt -q login_shell && : || return 0
echo -e "\033[0;32m
 ██╗  ██╗ █████╗ ███████╗
 ██║ ██╔╝██╔══██╗██╔════╝
 █████╔╝ ╚█████╔╝███████╗
 ██╔═██╗ ██╔══██╗╚════██║
 ██║  ██╗╚█████╔╝███████║
 ╚═╝  ╚═╝ ╚════╝ ╚══════ by lework\033[0m"

# os
upSeconds="\$(cut -d. -f1 /proc/uptime)"
secs=\$((\${upSeconds}%60))
mins=\$((\${upSeconds}/60%60))
hours=\$((\${upSeconds}/3600%24))
days=\$((\${upSeconds}/86400))
UPTIME_INFO=\$(printf "%d days, %02dh %02dm %02ds" "\$days" "\$hours" "\$mins" "\$secs")

if [ -f /etc/redhat-release ] ; then
    PRETTY_NAME=\$(< /etc/redhat-release)

elif [ -f /etc/debian_version ]; then
   DIST_VER=\$(</etc/debian_version)
   PRETTY_NAME="\$(grep PRETTY_NAME /etc/os-release | sed -e 's/PRETTY_NAME=//g' -e  's/"//g') (\$DIST_VER)"

else
    PRETTY_NAME=\$(cat /etc/*-release | grep "PRETTY_NAME" | sed -e 's/PRETTY_NAME=//g' -e 's/"//g')
fi

]],
    'if [[ -d "/system/app/" && -d "/system/priv-app" ]]; then',
    [[  model="\$(getprop ro.product.brand) \$(getprop ro.product.model)" ]],

    'elif [[ -f /sys/devices/virtual/dmi/id/product_name ||',
       ' -f /sys/devices/virtual/dmi/id/product_version ]]; then',
    [[     model="\$(< /sys/devices/virtual/dmi/id/product_name)" ]],
    [[     model+=" \$(< /sys/devices/virtual/dmi/id/product_version)" ]],

    'elif [[ -f /sys/firmware/devicetree/base/model ]]; then',
        [[  model="\$(< /sys/firmware/devicetree/base/model)" ]],

    'elif [[ -f /tmp/sysinfo/model ]]; then',
        [[  model="\$(< /tmp/sysinfo/model)" ]],
    'fi',
[[
MODEL_INFO=\${model}
KERNEL=\$(uname -srmo)
USER_NUM=\$(who -u | wc -l)
RUNNING=\$(ps ax | wc -l | tr -d " ")

# disk
totaldisk=\$(df -h -x devtmpfs -x tmpfs -x debugfs -x aufs -x overlay --total 2>/dev/null | tail -1)
disktotal=\$(awk '{print \$2}' <<< "\${totaldisk}")
diskused=\$(awk '{print \$3}' <<< "\${totaldisk}")
diskusedper=\$(awk '{print \$5}' <<< "\${totaldisk}")
DISK_INFO="\033[0;33m\${diskused}\033[0m of \033[1;34m\${disktotal}\033[0m disk space used (\033[0;33m\${diskusedper}\033[0m)"

# cpu
cpu=\$(awk -F':' '/^model name/ {print \$2}' /proc/cpuinfo | uniq | sed -e 's/^[ \t]*//')
cpun=\$(grep -c '^processor' /proc/cpuinfo)
cpuc=\$(grep '^cpu cores' /proc/cpuinfo | tail -1 | awk '{print \$4}')
cpup=\$(grep '^physical id' /proc/cpuinfo | wc -l)
CPU_INFO="\${cpu} \${cpup}P \${cpuc}C \${cpun}L"

# get the load averages
read one five fifteen rest < /proc/loadavg
LOADAVG_INFO="\033[0;33m\${one}\033[0m / \${five} / \${fifteen} with \033[1;34m\$(( cpun*cpuc ))\033[0m core(s) at \033[1;34m\$(grep '^cpu MHz' /proc/cpuinfo | tail -1 | awk '{print \$4}')\033 MHz"

# mem
MEM_INFO="\$(cat /proc/meminfo | awk '/MemTotal:/{total=\$2/1024/1024;next} /MemAvailable:/{use=total-\$2/1024/1024; printf("\033[0;33m%.2fGiB\033[0m of \033[1;34m%.2fGiB\033[0m RAM used (\033[0;33m%.2f%%\033[0m)",use,total,(use/total)*100);}')"

# network
# extranet_ip=" and \$(curl -s ip.cip.cc)"
IP_INFO="\$(ip a | grep glo | awk '{print \$2}' | head -1 | cut -f1 -d/)\${extranet_ip:-}"

# Container info
CONTAINER_INFO="\$(sudo /usr/bin/crictl ps -a -o yaml 2> /dev/null | awk '/^  state: /{gsub("CONTAINER_", "", \$NF) ++S[\$NF]}END{for(m in S) printf "%s%s:%s ",substr(m,1,1),tolower(substr(m,2)),S[m]}')Images:\$(sudo /usr/bin/crictl images -q 2> /dev/null | wc -l)"

# info
echo -e "
 Information as of: \033[1;34m\$(date +"%Y-%m-%d %T")\033[0m
 
 \033[0;1;31mProduct\033[0m............: \${MODEL_INFO}
 \033[0;1;31mOS\033[0m.................: \${PRETTY_NAME}
 \033[0;1;31mKernel\033[0m.............: \${KERNEL}
 \033[0;1;31mCPU\033[0m................: \${CPU_INFO}

 \033[0;1;31mHostname\033[0m...........: \033[1;34m\$(hostname)\033[0m
 \033[0;1;31mIP Addresses\033[0m.......: \033[1;34m\${IP_INFO}\033[0m

 \033[0;1;31mUptime\033[0m.............: \033[0;33m\${UPTIME_INFO}\033[0m
 \033[0;1;31mMemory\033[0m.............: \${MEM_INFO}
 \033[0;1;31mLoad Averages\033[0m......: \${LOADAVG_INFO}
 \033[0;1;31mDisk Usage\033[0m.........: \${DISK_INFO} 

 \033[0;1;31mUsers online\033[0m.......: \033[1;34m\${USER_NUM}\033[0m
 \033[0;1;31mRunning Processes\033[0m..: \033[1;34m\${RUNNING}\033[0m
 \033[0;1;31mContainer Info\033[0m.....: \${CONTAINER_INFO}
"
EOF

chmod +x /etc/profile.d/zz-ssh-login-info.sh
echo 'ALL ALL=NOPASSWD: /usr/bin/crictl info' > /etc/sudoers.d/crictl

  ]]
  }


  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end


function set_ntp(prev)
  local df = resource.shell.new("echo '8' || true")
  df.mute = true
  local cmd = [[
ntpd --version > /dev/null 2>1 && apt-get remove -y ntp
apt-get install -y chrony
[ ! -f /etc/chrony.conf_bak ] && cp /etc/chrony.conf{,_bak} #备份默认配置
cat << EOF > /etc/chrony.conf
server ntp.aliyun.com iburst
server cn.ntp.org.cn iburst
server ntp.shu.edu.cn iburst
server 0.cn.pool.ntp.org iburst
server 1.cn.pool.ntp.org iburst
server 2.cn.pool.ntp.org iburst
server 3.cn.pool.ntp.org iburst

driftfile /var/lib/chrony/drift
makestep 1.0 3
logdir /var/log/chrony
EOF

timedatectl set-timezone Asia/Shanghai
chronyd -q -t 1 'server cn.pool.ntp.org iburst maxsamples 1'
systemctl enable chronyd
systemctl start chronyd
chronyc sources -v
chronyc sourcestats
  ]]

  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end

function set_ipvs(prev)
  local df = resource.shell.new("echo '9' || true")
  df.mute = true
  local cmds = {
    "apt-get install -y ipvsadm ipset sysstat conntrack libseccomp2",
    [[
:> /etc/modules-load.d/ipvs.conf
module=(
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
br_netfilter
)
for kernel_module in ${module[@]};do
    /sbin/modinfo -F filename $kernel_module |& grep -qv ERROR && echo $kernel_module >> /etc/modules-load.d/ipvs.conf || :
done
# systemctl enable --now systemd-modules-load.service

ipvsadm --clear
    ]]

  } 

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end

function set_auditd(prev)
  local df = resource.shell.new("echo '10' || true")
  df.mute = true

  local cmd = [[
  apt-get install -y auditd audispd-plugins
cat << EOF > /etc/audit/rules.d/audit.rules

# Remove any existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Ignore errors
-i

# docker
-w /usr/bin/dockerd -k docker
-w /var/lib/docker -k docker
-w /etc/docker -k docker
-w /usr/lib/systemd/system/docker.service -k docker
-w /etc/systemd/system/docker.service -k docker
-w /usr/lib/systemd/system/docker.socket -k docker
-w /etc/default/docker -k docker
-w /etc/sysconfig/docker -k docker
-w /etc/docker/daemon.json -k docker

# containerd
-w /usr/bin/containerd -k containerd
-w /var/lib/containerd -k containerd
-w /usr/lib/systemd/system/containerd.service -k containerd
-w /etc/containerd/config.toml -k containerd

# runc
-w /usr/bin/runc -k runc

# kube
-w /usr/bin/kubeadm -k kubeadm
-w /usr/bin/kubelet -k kubelet
-w /usr/bin/kubectl -k kubectl
-w /var/lib/kubelet -k kubelet
-w /etc/kubernetes -k kubernetes
EOF
chmod 600 /etc/audit/rules.d/audit.rules
sed -i 's#max_log_file =.*#max_log_file = 80#g' /etc/audit/auditd.conf

systemctl stop auditd && systemctl start auditd
systemctl enable auditd
  ]]

  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end


function change_dns_option(prev)
  local df = resource.shell.new("echo '11' || true")
  df.mute = true

  local cmd = "grep single-request-reopen /etc/resolv.conf || sed -i '1ioptions timeout:2 attempts:3 rotate single-request-reopen' /etc/resolv.conf"

  ds = resource.shell.new(cmd)
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
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
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
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end

function set_hostname(prev)
  local df = resource.shell.new("echo '13' || true")
  df.mute = true

  local cmd = "hostnamectl set-hostname k8s-master-node1"
  ds = resource.shell.new(cmd)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df
end

function upgrade_kernel(prev)
  local df = resource.shell.new("echo '14' || true")
  df.mute = true
  codename = utils.ubuntu_codename()

  local cmds = {
  string.format('echo "deb [trusted=yes] http://mirrors.aliyun.com/ubuntu %s-backports main" > /etc/apt/sources.list.d/backports.list', codename),
  "apt update",
  string.format('apt -t "%s-backports" install linux-headers-generic linux-image-generic -y', codename)
  }

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)

  return df

end

function check_dns_host(prev)

  target = "k8s-master-node"
  if utils.line_exists("/etc/hosts", target) then
    -- df:pushRequire(prev:ID())
--
    -- catalog.add(df)
    -- return df
    return
  end

  local cmds = {
    "cat << EOF >> /etc/hosts"
  }

  local df = resource.shell.new("echo '15' || true")
  df.mute = true

  for ip, name in pairs(hostnames) do
    cmds[#cmds+1] = string.format("%s %s", ip, name)
  end
  cmds[#cmds+1] = "EOF"

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)
 
  return df
end

function install_kube(prev)
  local df = resource.shell.new("echo '16' || true")
  df.mute = true

  local cmds = {
"echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list",
"curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - ",
[[
apt-get update

export KUBE_VERSION="1.20.5"
apt-get install -y kubeadm=$KUBE_VERSION-00 kubelet=$KUBE_VERSION-00 kubectl=$KUBE_VERSION-00
sudo apt-mark hold kubelet kubeadm kubectl

[ -d /etc/bash_completion.d ] && \
    { kubectl completion bash > /etc/bash_completion.d/kubectl; \
      kubeadm completion bash > /etc/bash_completion.d/kubadm; }
      
[ ! -d /usr/lib/systemd/system/kubelet.service.d ] && mkdir -p /usr/lib/systemd/system/kubelet.service.d
cat << EOF > /usr/lib/systemd/system/kubelet.service.d/11-cgroup.conf
[Service]
CPUAccounting=true
MemoryAccounting=true
BlockIOAccounting=true
ExecStartPre=/usr/bin/bash -c '/usr/bin/mkdir -p /sys/fs/cgroup/{cpuset,memory,systemd,pids,"cpu,cpuacct"}/{system,kube,kubepods}.slice'
Slice=kube.slice
EOF
systemctl daemon-reload
 
systemctl enable kubelet.service
]]
}

  local cmds_list = table.concat(cmds, "\n")
  ds = resource.shell.new(cmds_list)
  ds.require = {prev:ID()}
  ds.mute = true
  df:pushRequire(ds:ID())
  catalog:add(ds, df)
 
  return df


end



df = disable_firewall()
re = repo(df)
da = disable_autoupdate(re)
dss = disable_selinux_swap(da) 
-- cl = change_limit(dss)
-- cs = change_sysctl(cl)
-- ch = change_history(cs)
csli = change_ssh_login_info(dss)
sn = set_ntp(csli)
si = set_ipvs(sn)
sa = set_auditd(si)
cdo = change_dns_option(sa)
idc = install_docker(cdo)
uk = upgrade_kernel(idc)
cdh = check_dns_host(uk)
ik = install_kube(uk)

