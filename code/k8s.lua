-- # 版本
-- KUBE_VERSION="${KUBE_VERSION:-latest}"
-- FLANNEL_VERSION="${FLANNEL_VERSION:-0.15.1}"
-- METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-0.5.2}"
-- INGRESS_NGINX="${INGRESS_NGINX:-1.1.0}"
-- TRAEFIK_VERSION="${TRAEFIK_VERSION:-2.5.6}"
-- CALICO_VERSION="${CALICO_VERSION:-3.21.2}"
-- CILIUM_VERSION="${CILIUM_VERSION:-1.9.11}"
-- KUBE_PROMETHEUS_VERSION="${KUBE_PROMETHEUS_VERSION:-0.9.0}"
-- ELASTICSEARCH_VERSION="${ELASTICSEARCH_VERSION:-7.16.2}"
-- ROOK_VERSION="${ROOK_VERSION:-1.8.1}"
-- LONGHORN_VERSION="${LONGHORN_VERSION:-1.2.3}"
-- KUBERNETES_DASHBOARD_VERSION="${KUBERNETES_DASHBOARD_VERSION:-2.4.0}"
-- KUBESPHERE_VERSION="${KUBESPHERE_VERSION:-3.2.1}"
--

version_config = {
  KUBE_VERSION = "latest",
  FLANNEL_VERSION = "0.15.1",
  METRICS_SERVER_VERSION = "0.5.2",
  INGRESS_NGINX = "1.1.0",
  TRAEFIK_VERSION = "2.5.6",
  CALICO_VERSION = "3.21.2",
  CILIUM_VERSION = "1.9.11",
  KUBE_PROMETHEUS_VERSION = "0.9.0",
  ELASTICSEARCH_VERSION = "7.16.2",
  ROOK_VERSION = "1.8.1",
  LONGHORN_VERSION = "1.2.3",
  KUBERNETES_DASHBOARD_VERSION = "2.4.0",
  KUBESPHERE_VERSION = "3.2.1",
}


-- # 集群配置
-- KUBE_DNSDOMAIN="${KUBE_DNSDOMAIN:-cluster.local}"
-- KUBE_APISERVER="${KUBE_APISERVER:-apiserver.$KUBE_DNSDOMAIN}"
-- KUBE_POD_SUBNET="${KUBE_POD_SUBNET:-10.244.0.0/16}"
-- KUBE_SERVICE_SUBNET="${KUBE_SERVICE_SUBNET:-10.96.0.0/16}"
-- KUBE_IMAGE_REPO="${KUBE_IMAGE_REPO:-registry.cn-hangzhou.aliyuncs.com/kainstall}"
-- KUBE_NETWORK="${KUBE_NETWORK:-flannel}"
-- KUBE_INGRESS="${KUBE_INGRESS:-nginx}"
-- KUBE_MONITOR="${KUBE_MONITOR:-prometheus}"
-- KUBE_STORAGE="${KUBE_STORAGE:-rook}"
-- KUBE_LOG="${KUBE_LOG:-elasticsearch}"
-- KUBE_UI="${KUBE_UI:-dashboard}"
-- KUBE_ADDON="${KUBE_ADDON:-metrics-server}"
-- KUBE_FLANNEL_TYPE="${KUBE_FLANNEL_TYPE:-vxlan}"
-- KUBE_CRI="${KUBE_CRI:-docker}"
-- KUBE_CRI_VERSION="${KUBE_CRI_VERSION:-latest}"
-- KUBE_CRI_ENDPOINT="${KUBE_CRI_ENDPOINT:-/var/run/dockershim.sock}"
--
KUBE_DNSDOMAIN="cluster.local"
KUBE_APISERVER="apiserver."..KUBE_DNSDOMAIN
KUBE_POD_SUBNET="10.244.0.0/16"
KUBE_SERVICE_SUBNET="-10.96.0.0/16"
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

--
-- # 定义的master和worker节点地址，以逗号分隔
-- MASTER_NODES="${MASTER_NODES:-}"
-- WORKER_NODES="${WORKER_NODES:-}"
--
MASTER_NODES=""
WORKER_NODES=""

-- # 定义在哪个节点上进行设置
-- MGMT_NODE="${MGMT_NODE:-127.0.0.1}"
--
MGMT_NODE="127.0.0.1"
-- # 节点的连接信息
-- SSH_USER="${SSH_USER:-root}"
-- SSH_PASSWORD="${SSH_PASSWORD:-}"
-- SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
-- SSH_PORT="${SSH_PORT:-22}"
-- SUDO_USER="${SUDO_USER:-root}"
--
--
SSH_USER="root"
SSH_PASSWORD=""
SSH_PRIVATE_KEY=""
SSH_PORT="22"
SUDO_USER="root"
-- # 节点设置
-- HOSTNAME_PREFIX="${HOSTNAME_PREFIX:-k8s}"
--
HOSTNAME_PREFIX="k8s"
-- # 脚本设置
-- GITHUB_PROXY="${GITHUB_PROXY:-https://gh.lework.workers.dev/}"
-- GCR_PROXY="${GCR_PROXY:-k8sgcr.lework.workers.dev}"
-- SKIP_UPGRADE_PLAN=${SKIP_UPGRADE_PLAN:-false}
-- SKIP_SET_OS_REPO=${SKIP_SET_OS_REPO:-false}
GITHUB_PROXY="https://gh.lework.workers.dev/"
GCR_PROXY="k8sgcr.lework.workers.dev"
SKIP_UPGRADE_PLAN=false
SKIP_SET_OS_REPO=false


-- run shell command: ls /var/log

ls = resource.shell.new("ls /var")

-- Finally, register the resources to the catalog
catalog:add(ls)

