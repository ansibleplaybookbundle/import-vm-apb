#!/bin/bash -x

set -e

QUAY_ORG=kubevirt

VM_NAME=${1}
USER=${2}
PASS=${3}
URI=${4}
NS=${5}
OS=${6:-linux}
TYPE=${7:-ovm}

die() { echo $@ >&2 ; exit 1 ; }

[[ "$VM_NAME" ]] || die "No vm name given"
[[ "$USER" ]] || die "No username given"
[[ "$PASS" ]] || die "No password given"
[[ "$URI" ]] || die "No source uri given"

DOMXML=$VM_NAME.xml

# create libvirt auth file
tee libvirt.auth <<EOF
[credentials-vmware]
authname=$USER
password=$PASS

[auth-esx-default]
credentials=vmware
EOF

# get vm domxml
export LIBVIRT_AUTH_FILE=libvirt.auth
virsh -c 'vpx://'$USER'@'$URI'?no_verify=1' dumpxml $VM_NAME >> $DOMXML
rm -f libvirt.auth

if [ ! -f $DOMXML ];
then
  die "Requested vm do not exists"
fi

# verify domxml for one disk and one nic
if [[ $(xmllint --xpath "count(//disk[@type='file']/source)" $DOMXML) -gt 1 ]];
then
  die "Only one disk per VM is supported ATM"
fi
if [[ $(xmllint --xpath "count(//interface[@type='bridge']/source)" $DOMXML) -gt 1 ]];
then
  die "Only one interface per VM is supported"
fi

# get disk location from domxml
dcPath=$(xmllint --xpath "/domain/*[local-name()='datacenterpath']/text()" $DOMXML)
diskSource=($(xmllint --xpath "string(//disk/source/@file)" $DOMXML))
rm -f $DOMXML
dsName=${diskSource[0]:1:-1}
fileName=$(echo ${diskSource[1]} | sed 's/\./-flat./g')

host=$(echo $URI | cut -d'/' -f-1)

# build disk uri
diskUri='https://'$host'/folder/'$fileName'?dcPath='$dcPath'&dsName='$dsName

# authenticate with vmware
curl --cookie-jar cookies.txt -q --max-redirs '5' --globoff --head --url $diskUri --user $USER':'$PASS --insecure
cookie=$(tail -n 1 cookies.txt | cut -f 7 | sed 's/"/\\"/g')
rm -f cookies.txt

# get disk size
qemu-img info 'json: { "file.cookie": "vmware_soap_session='$cookie'", "file.sslverify": "off", "file.driver": "https", "file.url": "'$diskUri'", "file.timeout": 2000 }' > output.txt
size=$(grep -Eow "[0-9]+[\.]?[0-9]+[MG]" output.txt)'i'
rm -f output.txt

# we support only one disk, it needs to be aligned with DNS-1123
PVCNAME=$(echo $VM_NAME-disk-01 | sed -r 's/[_.]+/-/g')
VMNAME=$(echo $VM_NAME | sed -r 's/[_.]+/-/g')

ENCODED_PASS=$(echo -n $PASS | base64)

# Create job template
tee template.yaml <<EOY
apiVersion: v1
kind: Template
metadata:
  name: v2v-job-template
  annotations:
    openshift.io/display-name: "KubeVirt v2v $VM_NAME Import"
    description: |
      A template to trigger a v2v job in order to import a VM from a remote
      vmware source into KubeVirt.
      Example
      libvirt $VM_NAME vpx://$USER@$URI?no_verify=1

parameters:
- name: SOURCE_TYPE
  description: "The VM source for this job (libvirt) see man virt-v2v"
  value: "ova"
- name: SOURCE_NAME
  decsription: "The name of the VM to import (name or URL)"
  value: "http://192.168.42.1/my.ova"
- name: SOURCE_URI
  description: "(Optional) The URI to connect to the remote instance"
- name: OS_TYPE
  description: "(Optional) OS type of the VM about to be imported"
- name: IMAGE_TYPE
  description: "(Optional) Specify whether to import VM as an offline vm or a template"

objects:
- apiVersion: v1
  kind: Secret
  metadata:
    name: v2v-secret
  type: Opaque
  data:
    password: $ENCODED_PASS
- apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: kubevirt-privileged
- apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: ClusterRole
  metadata:
    name: kubevirt-v2v
    labels:
      kubevirt.io: ""
  rules:
    - apiGroups:
      - kubevirt.io
      resources:
      - offlinevirtualmachines
      verbs:
        - get
        - list
        - watch
        - delete
        - update  
        - create  
        - deletecollection
- apiVersion: authorization.openshift.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: v2v-binding
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: kubevirt-v2v
  subjects:
  - kind: ServiceAccount
    name: kubevirt-privileged
    namespace: $NS
- kind: Job
  apiVersion: batch/v1 
  metadata:
    name: v2v-$VMNAME
  spec:
    backoffLimit: 1
    template:
      spec:
        serviceAccountName: kubevirt-privileged
        restartPolicy: Never
        containers:
        - name: v2v
          image: quay.io/$QUAY_ORG/v2v-job
          args: ["/v2v-dst",
                 "\${SOURCE_TYPE}",
                 "\${SOURCE_NAME}",
                 "\${SOURCE_URI}",
                 "\${OS_TYPE}",
                 "\${IMAGE_TYPE}",
                 "\${size}]",]
          env:
          - name: "DEBUG"
            value: "1"
          - name: SOURCE_PASSWORD
            valueFrom:
              secretKeyRef:
                name: v2v-secret
                key: password
          securityContext:
            privileged: true
          volumeMounts:
          - name: kvm
            mountPath: /dev/kvm
          - name: volume-1
            mountPath: /v2v-dst
          - name: volume-2
            mountPath: /var/tmp
        volumes:
        - name: kvm
          hostPath:
            path: /dev/kvm
        - name: volume-1
          persistentVolumeClaim:
            claimName: $PVCNAME
        - name: volume-2
          persistentVolumeClaim:
            claimName: temp
- kind: PersistentVolumeClaim
  apiVersion: v1
  metadata:
    name: $PVCNAME
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: $size
- kind: PersistentVolumeClaim
  apiVersion: v1
  metadata:
    name: temp
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1100Mi
EOY

# create the job
oc process --local -f template.yaml -p SOURCE_TYPE=libvirt -p SOURCE_NAME=$VM_NAME -p SOURCE_URI=vpx://$USER@$URI?no_verify=1 -p OS_TYPE=$OS -p IMAGE_TYPE=$TYPE | oc apply -f -

rm -f template.yaml
