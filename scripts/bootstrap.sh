#!/usr/bin/env bash

install_curl()
{
	# install docker dependencies
	sudo apt-get update -y && sudo apt-get install -y --allow-unauthenticated --no-install-recommends \
	curl &&
	apt-get clean
}

install_kubectl()
{
	# TODO Pin kubectl version
	# Download and move kubectl into /usr/local/bin
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/
}

install_docker()
{
	# install docker dependencies
	sudo apt-get update -y && sudo apt-get install -y --allow-unauthenticated --no-install-recommends \
	apt-transport-https \
	ca-certificates \
	software-properties-common &&
	apt-get clean

	# Install docker
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

	# TODO: 13/10/2019 - Morteza, we either use Linux Mint or Arch Linux as our development environment. For those using Linux Mint, following command
	# won't work. Instead of running "lsb_release -cs", we need to retrieve UBUNTU_CODENAME from /etc/os-release
	sudo add-apt-repository \
	"deb https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) \
	stable"

	# TODO Pin docker version
	sudo apt-get install -y --allow-unauthenticated docker-ce docker-ce-cli containerd.io

	# This enables non-root user to run docker without sudo
	sudo usermod -aG docker $USER
}

install_go()
{
	curl -Lo go.tar.gz https://dl.google.com/go/go1.13.1.linux-amd64.tar.gz
	sudo tar -C /usr/local -xzf go.tar.gz
	rm go.tar.gz

	echo "Make sure you add /usr/local/go to your $PATH and set your $GOPATH environment variable correctly"

}

install_kind()
{
	curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.5.1/kind-linux-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin/
}

install_helm()
{
	curl -Lo ./helm.tar.gz https://get.helm.sh/helm-v3.0.0-beta.4-linux-amd64.tar.gz
	mkdir ./helm
	tar -C ./helm -xzf helm.tar.gz
	sudo mv ./helm/linux-amd64/helm /usr/local/bin/
	rm -rf ./helm
	rm -rf helm.tar.gz
}

###
# Script Main (POSIX COMPLIANT)
###

# Ensure that this bootstrap is running on an Ubuntu machine
cat /etc/os-release | grep -i ubuntu
if [[ $? -ne 0 ]]; then
	echo "This bootstrap was made for Ubuntu machines only. Please manually install the dependencies."
fi

# List of dependencies that are required to deploy a K8s cluster locally with KIND
readonly dependencies="curl kubectl docker go kind helm"

for dep in $dependencies; do
	command -v $dep &>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "$dep does not exist. Installing $dep..."
		install_$dep
		echo "Finished installing $dep"
	fi
done


