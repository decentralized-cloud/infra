#!/usr/bin/env bash

set -e
set -x

current_directory=$(dirname "$0")
cd "$current_directory"/..

DEFAULT_CONFIG=./config/default_kind_config.yaml
KIND_CONFIG="${KIND_CONFIG:-"$DEFAULT_CONFIG"}"

DEFAULT_METALLB_CONFIG=./config/default_metallb_config.yaml

KEYPAIR_FILE_PATH=./certificates/ca.key
CERTIFICATE_FILE_PATH=./certificates/ca.crt
CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG=./config/cert-manager/self-signing-clusterissuer.yaml
CERT_MANAGER_FRONTEND_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/cert-manager/frontend-edge-cloud-certificate.yaml
CERT_MANAGER_API_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/cert-manager/api-edge-cloud-certificate.yaml
CERT_MANAGER_IDP_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/cert-manager/idp-edge-cloud-certificate.yaml
CERT_MANAGER_IDP_HEADLESS_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/cert-manager/idp-headless-edge-cloud-certificate.yaml

ISTIO_KIALI_SECRET_CONFIG=./config/istio/kiali_secret.yaml
ISTIO_GATEWAY_CONFIG=./config/istio/gateway.yaml
ISTIO_VIRTUALSERVICE_FRONTEND_CONFIG=./config/istio/frontend-virtualservice.yaml
ISTIO_VIRTUALSERVICE_API_CONFIG=./config/istio/api-virtualservice.yaml
ISTIO_VIRTUALSERVICE_IDP_CONFIG=./config/istio/idp-virtualservice.yaml
ISTIO_VIRTUALSERVICE_IDP_HEADLESS_CONFIG=./config/istio/idp-headless-virtualservice.yaml

DEFAULT_SERVICES_CONFIG=./config/edge_services.json

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

	# deploying metallb
	kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
	kubectl apply -f "$DEFAULT_METALLB_CONFIG"

	# installing cert-manager
	kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
	kubectl create namespace cert-manager
	helm install cert-manager \
		jetstack/cert-manager  \
		--version v0.12.0 \
		-n cert-manager \
		--wait
	kubectl create secret tls ca-key-pair --key="$KEYPAIR_FILE_PATH" --cert="$CERTIFICATE_FILE_PATH" -n cert-manager
	kubectl apply -n cert-manager -f "$CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG"

    # configuring edge namespace requirements
	kubectl create namespace edge
	kubectl label namespace edge istio-injection=enabled # labeling the edge namespace to enable automatic istio sidecar injection

	# deploying istio
	istioctl manifest apply \
		--set values.global.mtls.enabled=true \
		--set values.global.controlPlaneSecurityEnabled=true \
		--set values.gateways.istio-ingressgateway.enabled=true \
		--set values.gateways.istio-ingressgateway.sds.enabled=true \
		--set values.gateways.istio-egressgateway.enabled=true \
		--set values.kiali.enabled=true \
		--set values.global.proxy.accessLogFile="/dev/stdout" \
		--set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true

	# installing Kiali dashboard
	kubectl apply -f "$ISTIO_KIALI_SECRET_CONFIG"
	echo "Enter 'istioctl dashboard kiali' to access kiali dashboard"

	# deploying mongodb, make sure you deploy after istio deployment is done, so it inject sidecar for mongodb
	helm install mongodb \
		stable/mongodb \
		--set volumePermissions.enabled=true \
		--set usePassword=false \
		-n edge \
		--wait

	helm install keycloak codecentric/keycloak \
		--set keycloak.password=password \
		--set keycloak.persistence.deployPostgres=true \
		--set keycloak.persistence.dbVendor=postgres \
		--set postgresql.postgresPassword=password \
		-n edge \
		--wait

	# applying istio ingress related config
	kubectl apply -n istio-system -f "$CERT_MANAGER_FRONTEND_EDGE_CLOUD_CERTIFICATE_CONFIG"
	kubectl apply -n istio-system -f "$CERT_MANAGER_API_EDGE_CLOUD_CERTIFICATE_CONFIG"
	kubectl apply -n istio-system -f "$CERT_MANAGER_IDP_EDGE_CLOUD_CERTIFICATE_CONFIG"
	kubectl apply -n istio-system -f "$CERT_MANAGER_IDP_HEADLESS_EDGE_CLOUD_CERTIFICATE_CONFIG"

	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_GATEWAY_CONFIG")
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_FRONTEND_CONFIG")
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_API_CONFIG")
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_IDP_CONFIG")
	kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_IDP_HEADLESS_CONFIG")

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
    helm install "$2" decentralized-cloud/"$2" -n edge --version "$helm_chart_version" --set app-version="$app_version" --wait
}

function deploy_frontend_service() {
    helm_chart_version="$(jq -r '."'"frontend"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"frontend"'".app_version' < "$1")"
    echo -e "\nInstalling helm chart for frontend helm_chart_version=$helm_chart_version app_version=$app_version\n"
    helm install "frontend" decentralized-cloud/"frontend" -n edge --version "$helm_chart_version" --set app-version="$app_version" --set pod.apiGateway.url="https://api.edge-cloud.com/graphql"  --wait
}

case $1 in
	start|stop|remove_services) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
	*) print_help "$0" ;;
esac
