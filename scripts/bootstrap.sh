#!/usr/bin/env bash

set -e

current_directory=$(dirname "$0")
cd "$current_directory"/..

install_curl()
{
    # install curl dependencies
    sudo apt-get install \
        -y \
        --allow-unauthenticated \
        --no-install-recommends \
        curl
}

install_kubectl()
{
    sudo apt-get update && sudo apt-get install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
}

install_docker()
{
    # install docker dependencies
    sudo apt-get install \
        -y \
        --allow-unauthenticated \
        --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        software-properties-common

    # Install docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # TODO: 13/10/2019 - Morteza, we either use Linux Mint or Arch Linux as our development environment. For those using Linux Mint, following command
    # won't work. Instead of running "lsb_release -cs", we need to retrieve UBUNTU_CODENAME from /etc/os-release
    sudo add-apt-repository \
        "deb https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"

    # TODO Pin docker version
    sudo apt-get install \
        -y \
        --allow-unauthenticated \
        docker-ce \
        docker-ce-cli \
        containerd.io

    # This enables non-root user to run docker without sudo
    sudo groupadd docker || true # Ensure that docker group is created
    sudo usermod -aG docker "$USER"
    sudo chmod 666 /var/run/docker.sock
}

install_go()
{
    curl -Lo go.tar.gz https://dl.google.com/go/go1.14.1.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz

    echo "Make sure you add /usr/local/go to your PATH and set your GOPATH environment variable correctly"
}

install_kind()
{
    curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv -f ./kind /usr/local/bin/ # Overwrite previous version
}

install_helm()
{
    curl -Lo ./helm.tar.gz https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz
    mkdir ./helm
    tar -C ./helm -xzf helm.tar.gz
    sudo mv -f ./helm/linux-amd64/helm /usr/local/bin/ # Overwrite previous version
    rm -rf ./helm
    rm -rf helm.tar.gz
}

install_istioctl()
{
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.5.1  sh -
    sudo mv -f istio-1.5.1/bin/istioctl /usr/local/bin/ # Overwrite previous version
    rm -rf istio-1.5.1
}

install_jq()
{
    sudo apt-get install jq -y
}

add_helm_repos()
{
    # Add helm stable repo and decentralized-cloud repo
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    helm repo add decentralized-cloud https://decentralized-cloud.github.io/helm

    # mongodb chart
    helm repo add bitnami https://charts.bitnami.com/bitnami

    # istio repo
    helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.5.1/charts/

    # cert-manager repo
    helm repo add jetstack https://charts.jetstack.io

    # keycloak repo
    helm repo add codecentric https://codecentric.github.io/helm-charts

    helm repo update
}

################
# Script Main #
##############

# Ensure that this bootstrap is running on an Ubuntu machine
if ! grep -i 'ubuntu\|debian' < /etc/os-release; then
    echo "This bootstrap was made for Ubuntu/Debian machines only. Please manually install the dependencies."
    exit 1
fi

sudo apt-get update -y

# List of dependencies that are required by the edge-cloud infra for different use cases
readonly dependencies="curl kubectl docker go kind helm istioctl jq"

force=false

if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    force=true
fi

for dep in $dependencies; do
    if ! command -v "$dep" &>/dev/null; then
        echo "$dep does not exist. Installing $dep..."
        install_"$dep"
        echo "Finished installing $dep"
    elif [ $force = true ]; then
        if [[ "kubectl helm istioctl kind go" == *"$dep"* ]]; then
            echo "Force installing $dep"
            install_"$dep"
            echo "Finished installing $dep"
        fi
    fi
done

add_helm_repos

sudo apt-get clean
