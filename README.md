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
The current design of this APB requires that an OpenShift User and corresponding
password be specified.  This is a temporary inconvenience which should be
removed in the near future.  Please be sure to choose an account that has
privileges to create resources (PVC and OfflineVirtualMachine) in the chosen
project. 

### Supported disk image formats
This APB relies on the
[Containerized Data Importer (CDI)](https://github.com/kubevirt/containerized-data-importer)
which is installed along with KubeVirt.  CDI can import images in raw and qcow2
format.  Compressed images in the gz and xz formats are supported.  

### Virtual Machine Types
The operating system installed in a virtual machine disk image may make certain
assumptions about the underlying hardware platform.  In order for the virtual
machine to run properly, choose a virtual machine type that most closely matches
the virtual machine being imported.  *Currently only 'default' is available but
more types will be added as needed.* 

### Parameters
| Parameter            | Default value | Options   | Comments  |
|:---------------------|:--------------|:----------|:----------|
| Openshift User       |               |           | *see above* |
| Openshift Password   |               |           | *see above* |
| Disk Image URL       |               |           | The location of the virtual machine disk image. |
| Virtual Machine Type | default       | <ul><li>default</li></ul> | *see above* |
| Virtual Machine Name |               |           | Choose a unique name for the new virtual machine. |
| Number of CPUs       | 1             |           | The number virtual CPU cores to assign to the virtual machine. |
| Memory               | 1024          |           | The amount of memory (in Megabytes) to assign to the virtual machine. |

## Import from VMWare
*Coming Soon!*
