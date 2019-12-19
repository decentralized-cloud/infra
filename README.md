# Edge Cloud Infrastructure

## Local Development Environment

### Dependencies

To deploy a K8s cluster locally, we require the following dependencies to be installed

- kind
- docker
- kubectl (administrative tool)

These dependencies can be installed by running the following command

    ./script/bootstrap.sh

\*NB: This bootstrap has been tailored for Ubuntu machines only. Bootstrap will fail if run on non-Ubuntu machines.

### Creation and Deployment of Local K8s Cluster

Once you run the bootstrap or have acquired all the infrastructure dependencies, you can run the following commands to deploy a 3 master 3 slave K8s cluster using the default config provided.

    # Create a cluster named "kind" (by default) using our kind cluster configuration
    kind create cluster --config ./config/default_kind_config.yaml

    # Now you should be able to interact with the cluster, for example...
    kubectl get nodes # To check nodes are there

    # Done? Tear down cluster
    kind delete cluster

Alternatively, you can use our helper script to deploy a cluster by using the commands below:

    # Define KIND_CONFIG environment variable to specify your own config
    # e.g. $ export KIND_CONFIG="/path/to/config/kind_config.yaml"
    ./script/edge-cloud.sh start # Creates a cluster using default config unless KIND_CONFIG is defined

    ./script/edge-cloud.sh stop # To tear down the cluster

### Deploying Decentralized Edge Services

There are currently two ways to deploy Edge services; first deploying with no config, which will pull the latest version of each service's helm chart, second with a config which specifies the version for each service. This can be done running the following commands:

    ./script/edge-cloud.sh deploy_services # Deploy latest version for all services
    ./script/edge-cloud.sh deploy_services --config ./config/common/edge-cloud/services.json # Modify services with pinned version specified in services.json

    ./script/edge-cloud.sh remove_services # To remove all services from cluster and Helm

### Using Private Docker Images (not from Docker Hub)

When developing with a K8s cluster via Kind (i.e. K8s inside docker), the cluster is isolated from the host environment and as a result, does not have access to the images that are on the host.
Images can be pulled from DockerHub however, if you are developing your own image that has not been uploaded to DockerHub, images must be loaded in. This can be achieved using the `kind load` command. Examples are shown below.

    docker save -o my_image_version.tar my_image:version
    kind load image-archive my_image_version.tar

Or alternatively, load a local image directly

    kind load docker-image my_image:version # There has been issues running this command, please use the above method if this does not work.

*NB: Please make sure that the imagePullPolicy is either set to `IfNotPresent` or `Never` to ensure that the image is pulled locally.*
