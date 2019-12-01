#!/usr/bin/env bash

DEFAULT_CONFIG="$(cd "$(dirname "$0")"; pwd -P)"/../config/default_kind_config.yaml
DEFAULT_METALLB_CONFIG="$(cd "$(dirname "$0")"; pwd -P)"/../config/default_metallb_config.yaml
DEFAULT_SERVICES_CONFIG="$(cd "$(dirname "$0")"; pwd -P)"/../config/edge_services.json
KIND_CONFIG="${KIND_CONFIG:-"$DEFAULT_CONFIG"}"

function print_help() {
	echo -e "Usage: $1 [command]\n"
    echo "Available Commands:"
    echo -e "\tstart \t\t\t\t\tStart Kind K8s cluster"
    echo -e "\tstop \t\t\t\t\tStop Kind K8s cluster"
    echo -e "\tdeploy_services <--config config_path>\tDeploy all edge services"
    echo -e "\tremove_services \t\t\tRemove all edge services"
}

function start() {
	kind create cluster --config "$KIND_CONFIG" --wait 5m # Block until control plane is ready

	# Deploy mongodb
	kubectl create namespace edge

	# installing mongodb
	helm install mongodb stable/mongodb --set volumePermissions.enabled=true -n edge --set usePassword=false

	#installing metallb
	kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
	kubectl apply -f "$DEFAULT_METALLB_CONFIG"

	# installing istio
	istioctl manifest apply --set values.global.mtls.enabled=true --set values.global.controlPlaneSecurityEnabled=true
}

function stop() {
	kind delete cluster
}

readonly EDGE_SERVICES="tenant api-gateway edge-cluster"

# TODO Clean up script
function deploy_services() {
    helm repo update

    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                print_help
                exit 0
                ;;
            --config)
                shift
                if test $# -gt 0; then
                    echo "$1"
                    if [[ -f "$1" ]]; then
                        for service in $EDGE_SERVICES; do
                            deploy_a_service "$1" "$service"
                        done

                        deploy_frontend_service "$1"
                        exit 0
                    else
                        echo "Config file does not exist."
                        exit 1
                    fi
                    break
                else
                    echo "Missing argument. Please specify path to service config file."
                    exit 1
                fi
                ;;
            *)
                echo "Invalid argument."
                print_help
                exit 1
        esac
    done

    for service in $EDGE_SERVICES; do
        deploy_a_service "$DEFAULT_SERVICES_CONFIG" "$service"
    done

    deploy_frontend_service "$DEFAULT_SERVICES_CONFIG"
}

function remove_services() {
    for service in $EDGE_SERVICES; do
        helm uninstall "$service" -n edge
    done

    helm uninstall "frontend" -n edge
}

function deploy_a_service() {
    helm_chart_version="$(jq -r '."'"$2"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"$2"'".app_version' < "$1")"
    echo -e "\nInstalling helm chart for $2 helm_chart_version=$helm_chart_version app_version=$app_version\n"
    helm install "$2" decentralized-cloud/"$2" -n edge --version "$helm_chart_version" --set app-version="$app_version"
}

function deploy_frontend_service() {
    api_gateway_external_ip_address=""
    while [ -z "$api_gateway_external_ip_address" ]; do
        echo "Waiting for API Gateway external IP address to be assigned..."
        api_gateway_external_ip_address=$(kubectl get svc --namespace edge api-gateway --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
        [ -z "$api_gateway_external_ip_address" ] && sleep 1
    done
    echo "API gateway External IP: $api_gateway_external_ip_address"

    helm_chart_version="$(jq -r '."'"frontend"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"frontend"'".app_version' < "$1")"
    echo -e "\nInstalling helm chart for frontend helm_chart_version=$helm_chart_version app_version=$app_version\n"
    helm install "frontend" decentralized-cloud/"frontend" -n edge --version "$helm_chart_version" --set app-version="$app_version" --set pod.apiGateway.url="http://$api_gateway_external_ip_address/graphql"
}

case $1 in
	start|stop|remove_services) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
	*) print_help "$0" ;;
esac
