#!/usr/bin/env bash

set -e

current_directory=$(dirname "$0")
cd "$current_directory"/..

install_curl()
{
	# install curl dependencies
	apt-get install -y --allow-unauthenticated --no-install-recommends curl
}

install_kubectl()
{
	# TODO Pin kubectl version
	# Download and move kubectl into /usr/local/bin
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	mv ./kubectl /usr/local/bin/
}

install_docker()
{
	# install docker dependencies
	apt-get install -y --allow-unauthenticated --no-install-recommends \
	apt-transport-https \
	ca-certificates \
	software-properties-common

	# Install docker
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

	# TODO: 13/10/2019 - Morteza, we either use Linux Mint or Arch Linux as our development environment. For those using Linux Mint, following command
	# won't work. Instead of running "lsb_release -cs", we need to retrieve UBUNTU_CODENAME from /etc/os-release
	add-apt-repository \
	"deb https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) \
	stable"

	# TODO Pin docker version
	apt-get install -y --allow-unauthenticated docker-ce docker-ce-cli containerd.io

	# This enables non-root user to run docker without sudo
	groupadd docker || true # Ensure that docker group is created
	usermod -aG docker "$USER"
	chmod 666 /var/run/docker.sock
}

install_go()
{
	curl -Lo go.tar.gz https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
	rm -rf /usr/local/go
	tar -C /usr/local -xzf go.tar.gz
	rm go.tar.gz

	echo "Make sure you add /usr/local/go to your PATH and set your GOPATH environment variable correctly"
}

install_kind()
{
	curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.6.1/kind-linux-amd64
	chmod +x ./kind
	mv ./kind /usr/local/bin/
}

install_helm()
{
	curl -Lo ./helm.tar.gz https://get.helm.sh/helm-v3.0.0-linux-amd64.tar.gz
	mkdir ./helm
	tar -C ./helm -xzf helm.tar.gz
	mv ./helm/linux-amd64/helm /usr/local/bin/
	rm -rf ./helm
	rm -rf helm.tar.gz
}

install_istioctl()
{
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.0  sh -
	mv istio-1.4.0/bin/istioctl /usr/local/bin/
	rm -rf istio-1.4.0
}

add_helm_repos()
{
	# Add helm stable repo and decentralized-cloud repo
	helm repo add stable https://kubernetes-charts.storage.googleapis.com/
	helm repo add decentralized-cloud https://decentralized-cloud.github.io/helm

	# istio repo
	helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.4.0/charts/

	# cert-manager repo
	helm repo add jetstack https://charts.jetstack.io

	# ory repo
	helm repo add ory https://k8s.ory.sh/helm/charts

	helm repo update
}

################
# Script Main #
##############

# Ensure that this bootstrap is running on an Ubuntu machine
if ! grep -i ubuntu < /etc/os-release; then
	echo "This bootstrap was made for Ubuntu machines only. Please manually install the dependencies."
	exit 1
fi

apt-get update -y && apt-get install jq -y

# List of dependencies that are required to deploy a K8s cluster locally with KIND
readonly dependencies="curl kubectl docker go kind helm istioctl"

for dep in $dependencies; do
	if ! command -v "$dep" &>/dev/null; then
		echo "$dep does not exist. Installing $dep..."
		install_"$dep"
		echo "Finished installing $dep"
	fi
done

add_helm_repos

apt-get clean
