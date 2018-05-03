#!/bin/bash

# FIXME Workaround for https://github.com/kubernetes/kubernetes/issues/55708
PLUGINDIR=./
[[ "$KUBECTL_PLUGINS_CALLER" ]] && {
  export PLUGINDIR=${1}
  shift 1
}

usage() {
  CMD=$0
  [[ "$KUBECTL_PLUGINS_CALLER" ]] && CMD="kubectl plugin pvc"
  cat <<EOM
Usage: $CMD import DOMNAME

This command will import the domain DOMNAME into KubeVirt
EOM
exit 1
}

fatal() { echo "FATAL: $@" >&2 ; exit 1 ; }
wait_running() { until [[ "$(kubectl get pod ${1} -o jsonpath='{.status.phase}')" == Running ]]; do sleep 1; done ; }

_import() {
  local DOMNAME=${1}

  set -e

  [[ "$DOMNAME" ]] || fatal "No domain name name given"

  kubectl get ovm $DOMNAME >/dev/null 2>&1 && \
    fatal "Offline Virtual Machine '$DOMNAME' already exists"

  virsh dumpxml $DOMNAME > dom.xml
  xsltproc $PLUGINDIR/data/toVMSpec.xsl dom.xml > vm.yaml
  kubectl create -f vm.yaml

  [[ "$(xmllint --xpath /domain/devices/disk dom.xml | grep "<disk" | wc -l)" -gt 1 ]] && die "Currently only VMs with 1 disk are supported."
  local DISKPATH=$(xmllint --xpath "string(/domain/devices/disk[1]/source/@file)" dom.xml)
  [[ -f $DISKPATH ]] || die "Disk '$DISKPATH' not found"
  local SIZEBYTES=$(qemu-img info "$DISKPATH" | egrep -o "[0-9]+ bytes" | egrep -o "[0-9]+")
  kubectl plugin pvc create $DOMNAME-disk-1 $(( $SIZEBYTES / 1024 / 1024 ))M $DISKPATH disk.img
}

main() {
  if [[ "${1}" == import ]];
  then
    local CMD=_${1}
    shift 1
    $CMD $@
  else
    fatal "Unknown command: ${1}"
  fi
}


if [[ ${#} == 0 || $@ == *-h* ]];
then
  usage
else
  main import $@
fi
