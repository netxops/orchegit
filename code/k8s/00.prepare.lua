--!/usr/bin/lua

-- # 版本
KUBE_VERSION="latest"
FLANNEL_VERSION="0.15.1"
METRICS_SERVER_VERSION="0.5.2"
INGRESS_NGINX="1.1.0"
TRAEFIK_VERSION="2.5.6"
CALICO_VERSION="3.21.2"
CILIUM_VERSION="1.9.11"
KUBE_PROMETHEUS_VERSION="0.9.0"
ELASTICSEARCH_VERSION="7.16.2"
ROOK_VERSION="1.8.1"
LONGHORN_VERSION="1.2.3"
KUBERNETES_DASHBOARD_VERSION="2.4.0"
KUBESPHERE_VERSION="3.2.1"

-- # 集群配置
KUBE_DNSDOMAIN="cluster.local"
KUBE_APISERVER="apiserver" .. KUBE_DNSDOMAIN
KUBE_POD_SUBNET="10.244.0.0/16"
KUBE_SERVICE_SUBNET="10.96.0.0/16"
KUBE_IMAGE_REPO="registry.cn-hangzhou.aliyuncs.com/kainstall"
KUBE_NETWORK="flannel"
KUBE_INGRESS="nginx"
KUBE_MONITOR="prometheus"
KUBE_STORAGE="rook"
KUBE_LOG="elasticsearch"
KUBE_UI="dashboard"
KUBE_ADDON="metrics-server"
KUBE_FLANNEL_TYPE="vxlan"
KUBE_CRI="docker"
KUBE_CRI_VERSION="latest"
KUBE_CRI_ENDPOINT="/var/run/dockershim.sock"

-- # 定义的master和worker节点地址，以逗号分隔
MASTER_NODES=""
WORKER_NODES=""

-- # 定义在哪个节点上进行设置
MGMT_NODE="127.0.0.1"

-- # 节点的连接信息
SSH_USER="root"
SSH_PASSWORD=""
SSH_PRIVATE_KEY=""
SSH_PORT="22"
SUDO_USER="root"

-- # 节点设置
HOSTNAME_PREFIX="k8s"

-- # 脚本设置
TMP_DIR="rm -rf /tmp/kainstall* && mktemp -d -t kainstall.XXXXXXXXXX"
LOG_FILE=TMP_DIR .. "/kainstall.log"
SSH_OPTIONS="-o ConnectTimeout=600 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ERROR_INFO="\n\033[31mERROR Summary: \033[0m\n  "
ACCESS_INFO="\n\033[32mACCESS Summary: \033[0m\n  "
COMMAND_OUTPUT=""
SCRIPT_PARAMETER="$*"
OFFLINE_DIR="/tmp/kainstall-offline-file/"
OFFLINE_FILE=""
OS_SUPPORT="ubuntu20.04 ubuntu20.10 ubuntu21.04"
GITHUB_PROXY="https://gh.lework.workers.dev/"
GCR_PROXY="k8sgcr.lework.workers.dev"
SKIP_UPGRADE_PLAN=false
SKIP_SET_OS_REPO=false


-- # hostnames

hostnames = {}
hostnames["10.46.9.23"] = "k8s-master-node1"

print(LOG_FILE)
