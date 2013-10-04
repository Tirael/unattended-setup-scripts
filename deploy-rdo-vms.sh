#!/bin/sh
set -e

if [ $# -ne 4 ]; then
    echo "Usage: $0 <datastore> <name> <switch> <nic>"
    exit 1
fi

BASEDIR=$(dirname $0)

DATASTORE=$1
RDO_NAME=$2
EXT_SWITCH=$3
VMNIC=$4

MGMT_NETWORK="$RDO_NAME"_mgmt
DATA_NETWORK="$RDO_NAME"_data
EXT_NETWORK="$RDO_NAME"_external

POOL_NAME=$RDO_NAME

LINUX_GUEST_OS=rhel6-64
HYPERV_GUEST_OS=winhyperv

LINUX_TEMPLATE=/vmfs/volumes/datastore1/centos-6.4-template/centos-6.4-template.vmdk
HYPERV_TEMPLATE=/vmfs/volumes/datastore1/hyperv-2012-template/hyperv-2012-template.vmdk

CONTROLLER_VM_NAME="$RDO_NAME"_controller
NETWORK_VM_NAME="$RDO_NAME"_network
QEMU_COMPUTE_VM_NAME="$RDO_NAME"_compute_qemu
HYPERV_COMPUTE_VM_NAME="$RDO_NAME"_compute_hyperv

POOL_ID=`$BASEDIR/get-esxi-resource-pool-id.sh $POOL_NAME`
if [ -z $POOL_ID ]; then
    $BASEDIR/create-esxi-resource-pool.sh $POOL_NAME
fi

PORTGROUP_EXISTS=`$BASEDIR/check-esxi-portgroup-exists.sh "$EXT_NETWORK"`
if [ -z "$PORTGROUP_EXISTS" ]; then
    /bin/vim-cmd hostsvc/net/portgroup_add "$EXT_SWITCH" "$EXT_NETWORK"
fi
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC "$EXT_SWITCH" "$EXT_NETWORK"

PORTGROUP_EXISTS=`$BASEDIR/check-esxi-portgroup-exists.sh "$MGMT_NETWORK"`
if [ -z "$PORTGROUP_EXISTS" ]; then
    /bin/vim-cmd hostsvc/net/portgroup_add "$EXT_SWITCH" "$MGMT_NETWORK"
fi
/bin/vim-cmd hostsvc/net/portgroup_set --nicorderpolicy-active=$VMNIC "$EXT_SWITCH" "$MGMT_NETWORK"

SWITCH_EXISTS=`$BASEDIR/check-esxi-switch-exists.sh "$DATA_NETWORK"`
if [ -z "$SWITCH_EXISTS" ]; then
    $BASEDIR/create-esxi-switch.sh "$DATA_NETWORK"
fi

$BASEDIR/delete-esxi-vm.sh "$CONTROLLER_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$NETWORK_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$QEMU_COMPUTE_VM_NAME" $DATASTORE
$BASEDIR/delete-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME" $DATASTORE

$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $CONTROLLER_VM_NAME $POOL_NAME 1024 2 2 11G $LINUX_TEMPLATE - - - false "$MGMT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $NETWORK_VM_NAME $POOL_NAME 1024 2 2 11G $LINUX_TEMPLATE - - - false "$MGMT_NETWORK" "$DATA_NETWORK" "$EXT_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $LINUX_GUEST_OS $QEMU_COMPUTE_VM_NAME $POOL_NAME 4096 2 2 30G $LINUX_TEMPLATE - - - false "$MGMT_NETWORK" "$DATA_NETWORK"
$BASEDIR/create-esxi-vm.sh $DATASTORE $HYPERV_GUEST_OS $HYPERV_COMPUTE_VM_NAME $POOL_NAME 4096 2 2 60G $HYPERV_TEMPLATE - - - false "$MGMT_NETWORK" "$DATA_NETWORK" 

#sleep 20

$BASEDIR/power-on-esxi-vm.sh "$CONTROLLER_VM_NAME"
$BASEDIR/power-on-esxi-vm.sh "$NETWORK_VM_NAME"
$BASEDIR/power-on-esxi-vm.sh "$QEMU_COMPUTE_VM_NAME"
$BASEDIR/power-on-esxi-vm.sh "$HYPERV_COMPUTE_VM_NAME"
