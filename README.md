# import-vm-apb

This *ansible playbook bundle* imports a Virtual Machine into a cluster with
[KubeVirt](http://www.kubevirt.io)
[APB](https://github.com/ansibleplaybookbundle/kubevirt-apb) installed.

Virtual machines can be imported from a URL or from VMWare (coming soon).

## Import from URL
To use this option, select the *Import from URL* plan.  You will need to supply
the location of a virtual machine disk image and other basic parameters to
define the new virtual machine.  Once deployed, a PVC is created and the disk
image is downloaded from the specified location.  A virtual machine is created
and associated with the imported disk image.

### Required credentials
The current design of this APB requires that an admin OpenShift User and 
corresponding password be specified for certain operations. This is a 
temporary inconvenience which should be removed in the near future. 

### Supported disk image formats
This APB relies on the
[Containerized Data Importer (CDI)](https://github.com/kubevirt/containerized-data-importer)
which is installed along with KubeVirt.  CDI can import images in raw and qcow2
format.  Compressed images in the gz and xz formats are supported.  

### Virtual Machine Types
The operating system installed in a virtual machine disk image may make certain
assumptions about the underlying hardware platform.  In order for the virtual
machine to run properly, choose a virtual machine type that most closely matches
the virtual machine being imported. 

### Parameters
| Parameter                | Default value | Options   | Comments  |
|:-------------------------|:--------------|:----------|:----------|
| Openshift Admin User     |               |           | Only needed to create templates |
| Openshift Admin Password |               |           | Only needed to create templates |
| Disk Image URL           |               |           | The location of the virtual machine disk image. |
| Virtual Machine Type     | linux         | <ul><li>linux</li><li>windows</li></ul> | |
| Virtual Machine Name     |               |           | Choose a unique name for the new virtual machine. |
| Number of CPUs           | 1             |           | The number virtual CPU cores to assign to the virtual machine. |
| Memory                   | 1024          |           | The amount of memory (in Megabytes) to assign to the virtual machine. |

## Import from VMWare
To use this option, select the *Import from VMWare* plan. You will need to supply
VMware's url from where you want to import, virtual machine name to be imported
and the VMware's administrator credentials. Once deployed, a virtual machine is
created with a PVC containing imported image from VMware.

###
In order for this apb to work you need at a minimum the following versions:
CDI: 1.2.0
KubeVirt: 0.9

### Limitations
At the moment we can import virtual machine having one disk and one network interface.

>Note:
After adding PVC name and pushing the newly build apb image to the broker, you would see 2 apb of the same name in the console. To avoid this, while editing the PVC details change the `displayName` of the apb under `metadata` in `apb.yml`
