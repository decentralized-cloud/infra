#!/bin/env bash

DEFAULT_CONFIG="$(cd "$(dirname "$0")"; pwd -P)"/../config/default_kind_config.yaml
KIND_CONFIG="${KIND_CONFIG:-"$DEFAULT_CONFIG"}"

function print_help() {
	echo "Usage: ./$1 <start|stop>"
}

function start() {
	kind create cluster --config "$KIND_CONFIG"
	export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
}

function stop() {
	kind delete cluster
}

case $1 in
	start|stop) "$1" ;;
	*) print_help "$0" ;;
esac
