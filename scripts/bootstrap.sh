#!/usr/bin/env sh

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
    curl \
    software-properties-common &&
    apt-get clean

    # Install docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    sudo add-apt-repository \
        "deb https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"

    # TODO Pin docker version
    sudo apt-get install -y --allow-unauthenticated docker-ce
}

install_go()
{
    # TODO Implement if needed.
    echo "Not implemented."
}

install_kind()
{

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
readonly dependencies="kubectl docker kind"
for dep in $dependencies; do
    command -v $dep &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "$dep does not exist. Installing $dep"
        install_$dep
    fi
done


