#!/usr/bin/env bash

CONFIG_PATH="$(cd "$(dirname "$0")"; pwd -P)"/../config/
DEFAULT_CONFIG="$CONFIG_PATH"/default_kind_config.yaml
DEFAULT_METALLB_CONFIG="$CONFIG_PATH"/default_metallb_config.yaml
DEFAULT_SERVICES_CONFIG="$CONFIG_PATH"/edge_services.json
ISTIO_KIALI_SECRET_CONFIG="$CONFIG_PATH"/istio/kiali_secret.yaml
ISTIO_GATEWAY_CONFIG="$CONFIG_PATH"/istio/gateway.yaml
ISTIO_VIRTUALSERVICE_CONFIG="$CONFIG_PATH"/istio/virtualservice.yaml
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
	kubectl create namespace edge

	# labeling the edge namespace to enable automatic istio sidecar injection
	kubectl label namespace edge istio-injection=enabled

	# deploying metallb
	kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
	kubectl apply -f "$DEFAULT_METALLB_CONFIG"

	# deploying istio
	istioctl manifest apply \
		--set values.global.mtls.enabled=true \
		--set values.global.controlPlaneSecurityEnabled=true \
		--set values.kiali.enabled=true \
        	--set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true
	kubectl apply -f "$ISTIO_KIALI_SECRET_CONFIG"

	echo "Enter 'istioctl dashboard kiali' to access kiali dashboard"

	# deploying mongodb, make sure you deploy after istio deployment is done, so it inject sidecar for mongodb
	helm install mongodb stable/mongodb --set volumePermissions.enabled=true -n edge --set usePassword=false

	# applying istio ingress related config
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_GATEWAY_CONFIG")
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_CONFIG")

	echo "You need to make sure edge-cloud.com is added to your /etc/hosts file locally"
	echo "If you are using kind, you most likely got 172.17.255.1 as its IP address"
	echo "Add following line to your /etc/hosts file:"
	echo "172.17.255.1 edge-cloud.com"
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
    helm_chart_version="$(jq -r '."'"frontend"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"frontend"'".app_version' < "$1")"
    echo -e "\nInstalling helm chart for frontend helm_chart_version=$helm_chart_version app_version=$app_version\n"
    helm install "frontend" decentralized-cloud/"frontend" -n edge --version "$helm_chart_version" --set app-version="$app_version" --set pod.apiGateway.url="http://edge-cloud.com/api/graphql"
}

case $1 in
	start|stop|remove_services) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
	*) print_help "$0" ;;
esac
