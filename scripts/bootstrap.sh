#!/usr/bin/env bash

set -e

current_directory=$(dirname "$0")
cd "$current_directory"/..

install_curl()
{
    # install curl dependencies
    sudo apt-get install \
        -y \
        curl
}

install_kubectl()
{
    sudo rm -f /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl kubelet kubeadm
}

install_docker()
{
    # install docker dependencies
    sudo apt-get install \
        -y \
        apt-transport-https \
        ca-certificates \
        gnupg-agent \
        software-properties-common

    # Install docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    dist_id=$(lsb_release -is)

    echo "Detected $dist_id"

    if [[ "$dist_id" == "Linuxmint" ]]; then
        sudo add-apt-repository \
            "deb https://download.docker.com/linux/ubuntu \
        $(awk -F= '$1=="UBUNTU_CODENAME" { print $2 ;}' /etc/os-release) \
            stable"
    elif [[ "$dist_id" == "Ubuntu" ]]; then
        sudo add-apt-repository \
            "deb https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
            stable"
    else
        echo "Distro $dist_id is not supported to install docker on"
        exit 1
    fi

    # TODO Pin docker version
    sudo apt-get install \
        -y \
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
    curl -Lo go.tar.gz https://dl.google.com/go/go1.18.1.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz

    echo "Make sure you add /usr/local/go to your PATH and set your GOPATH environment variable correctly"
}

install_kind()
{
    curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.11.1/kind-linux-amd64
    chmod +x ./kind
    sudo mv -f ./kind /usr/local/bin/ # Overwrite previous version
}

install_helm()
{
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm -f get_helm.sh
}

install_istioctl()
{
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.12.2  sh -
    sudo mv -f istio-1.12.2/bin/istioctl /usr/local/bin/ # Overwrite previous version
    rm -rf istio-1.12.2
}

install_jq()
{
    sudo apt-get install jq -y
}

install_telepresence()
{
    dist_id=$(lsb_release -is)

    echo "Detected $dist_id"

    if [[ "$dist_id" == "Linuxmint" ]]; then
        curl -sO https://packagecloud.io/install/repositories/datawireio/telepresence/script.deb.sh
        sudo env os=ubuntu dist=$(awk -F= '$1=="UBUNTU_CODENAME" { print $2 ;}' /etc/os-release) bash script.deb.sh
        sudo apt install --no-install-recommends -y telepresence
        rm script.deb.sh
    elif [[ "$dist_id" == "Ubuntu" ]]; then
        curl -s https://packagecloud.io/install/repositories/datawireio/telepresence/script.deb.sh | sudo bash
        sudo apt install --no-install-recommends -y telepresence
    else
        echo "Distro $dist_id is not supported to install telepresence on"
        exit 1
    fi
}

install_python3()
{
    sudo apt-get install python3 -y
}

install_pip3()
{
    sudo apt-get install python3-pip -y
}

add_helm_repos()
{
    # Add helm stable repo repo
    helm repo add stable https://charts.helm.sh/stable

    # Add decentralized-cloud repo
    helm repo add decentralized-cloud https://decentralized-cloud.github.io/helm

    # mongodb repo
    helm repo add bitnami https://charts.bitnami.com/bitnami

    # cert-manager repo
    helm repo add jetstack https://charts.jetstack.io

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
readonly dependencies="curl kubectl docker go kind helm istioctl jq telepresence python3 pip3"

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
        if [[ "curl kubectl helm istioctl kind go telepresence python3 pip3" == *"$dep"* ]]; then
            echo "Force installing $dep"
            install_"$dep"
            echo "Finished installing $dep"
        fi
    fi
done

add_helm_repos

sudo apt-get clean
