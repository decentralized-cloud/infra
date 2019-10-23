# Edge Cloud Infrastructure

## Local Development Environment

### Dependencies

To deploy a K8s cluster locally, we require the following dependencies to be installed

- kind
- docker
- kubectl (administrative tool)

These dependencies can be installed by running the following command
    
    sudo ./script/bootstrap.sh

\*NB: This bootstrap has been tailored for Ubuntu machines only. Bootstrap will fail if run on non-Ubuntu machines.

### Creation and Deployment of local K8s cluster

Once you run the bootstrap or have acquired all the infrastructure dependencies, you can run the following commands to deploy a 3 master 3 slave K8s cluster using the default config provided.

    # Create a cluster named "kind" (by default) using our kind cluster configuration
    kind create cluster --config ./config/default_kind_config.yaml

    # If you successfully create a cluster, you should be able to export the config as below.
    export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

    # Now you should be able to interact with the cluster, for example...
    kubectl get nodes # To check nodes are there
    
    # Done? Tear down cluster
    kind delete cluster

Alternatively, you can use our helper script to deploy a cluster by using the commands below:

    # Define KIND_CONFIG environment variable to specify your own config
    # e.g. $ export KIND_CONFIG="/path/to/config/kind_config.yaml"
    ./script/edge-cloud start # Creates a cluster using default config unless KIND_CONFIG is defined

    ./script/edge-cloud stop # To tear down the cluster
