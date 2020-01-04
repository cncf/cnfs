# USE_RESERVED=${USE_RESERVED:-false}
# DEPLOY_NAME=${DEPLOY_NAME:-cnftestbed}
# PACKET_FACILITY=${PACKET_FACILITY:-sjc1}
# PACKET_OS=${PACKET_OS:-ubuntu_16_04}
# MASTER_COUNT=${MASTER_COUNT:-1}
# WORKER_COUNT=${WORKER_COUNT:-1}
# PACKET_FACILITY=${PACKET_FACILITY:-sjc1}
# VLAN_SEGMENT=${VLAN_SEGMENT:-$DEPLOY_NAME}
# PLAYBOOK=${PLAYBOOK:-k8s_worker_vswitch_quad_intel.yml}
# RELEASE_TYPE=${RELEASE_TYPE:-stable}
# HOSTS_FILE=${HOSTS_FILE:-$(pwd)/data/$DEPLOY_NAME/nodes.env}

PROJECT_ROOT := $$(pwd -P)
DEPLOY_NAME := cnftestbed
NIC_FILE = $(PROJECT_ROOT)/data/$(DEPLOY_NAME)/packet_gen_nics.env
KUBECONFIG := $(PROJECT_ROOT)/data/$(DEPLOY_NAME)/mycluster/artifacts/admin.conf
PLAYBOOK := k8s_worker_vswitch_quad_intel.yml

.PHONY: hw_k8s
hw_k8s : STATE_FILE=$(PROJECT_ROOT)/data/$(DEPLOY_NAME)/kubernetes.tfstate
hw_k8s : NODE_FILE=$(PROJECT_ROOT)/data/$(DEPLOY_NAME)/kubernetes.env
hw_k8s : NODE_GROUP_ONE_NAME=$(DEPLOY_NAME)-master
hw_k8s : NODE_GROUP_TWO_NAME=$(DEPLOY_NAME)-worker
hw_k8s : NODE_GROUP_ONE_COUNT = 3
hw_k8s : NODE_GROUP_TWO_COUNT = 1
hw_k8s : NODE_GROUP_ONE_DEVICE_PLAN = m2.xlarge.x86
hw_k8s : NODE_GROUP_TWO_DEVICE_PLAN = n2.xlarge.x86
hw_k8s: hw

.PHONY: hw_pktgen
hw_pktgen : STATE_FILE=$(PROJECT_ROOT)/data/$(DEPLOY_NAME)/packet_gen.tfstate
hw_pktgen : NODE_FILE=$(PROJECT_ROOT)/data/$(DEPLOY_NAME)/packet_gen.env
hw_pktgen : NODE_GROUP_ONE_NAME=$(DEPLOY_NAME)-pktgen
hw_pktgen : NODE_GROUP_ONE_COUNT = 1
hw_pktgen : NODE_GROUP_TWO_COUNT = 0
hw_pktgen : NODE_GROUP_ONE_DEVICE_PLAN = n2.xlarge.x86
hw_pktgen: hw

hw:
	NODE_GROUP_ONE_NAME=$(NODE_GROUP_ONE_NAME) NODE_GROUP_TWO_NAME=$(NODE_GROUP_TWO_NAME) NODE_GROUP_ONE_COUNT=$(NODE_GROUP_ONE_COUNT) NODE_GROUP_TWO_COUNT=$(NODE_GROUP_TWO_COUNT) NODE_GROUP_ONE_DEVICE_PLAN=$(NODE_GROUP_ONE_DEVICE_PLAN) NODE_GROUP_TWO_DEVICE_PLAN=$(NODE_GROUP_TWO_DEVICE_PLAN) STATE_FILE=$(STATE_FILE) NODE_FILE=$(NODE_FILE) tools/hardware_provisioning.sh

.PHONY: k8s
k8s: config provision

config:
	tools/kubernetes_provisioning.sh generate_config

provision:
	tools/kubernetes_provisioning.sh provision

vswitch:
	PROJECT_ROOT=$(PROJECT_ROOT) PLAYBOOK=$(PLAYBOOK) tools/kubernetes_provisioning.sh vswitch

pktgen:
	PROJECT_ROOT=$(PROJECT_ROOT) NIC_FILE=$(NIC_FILE) tools/packet_generator_provisioning.sh
  PKTGEN_ETH2 := $$(cat $(NIC_FILE) | awk 'NR==1{print $1}')
  PKTGEN_ETH3 := $$(cat $(NIC_FILE) | awk 'NR==2{print $1}')

snake:
	docker run -v $(KUBECONFIG):/tmp/admin.conf -v $(PROJECT_ROOT)/examples/use_case/3c2n-csc/:/tmp/3c2n-csc -e KUBECONFIG=/tmp/admin.conf -ti alpine/helm install csc --set nfvbench_macs={$(PKTGEN_ETH2),$(PKTGEN_ETH3)} /tmp/3c2n-csc/csc/