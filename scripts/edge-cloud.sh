#!/usr/bin/env bash

set -e
set -x

current_directory=$(dirname "$0")
cd "$current_directory"/..

# Common Config
ISTIO_KIALI_SECRET_CONFIG=./config/common/istio/kiali_secret.yaml
EDGE_CLOUD_SERVICES_CONFIG=./config/common/edge-cloud/services.json

function set_local_variable() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        KIND_CONFIG="${KIND_CONFIG:-./config/local/kind_config.yaml}"

        # metallb
        METALLB_CONFIG=./config/local/metallb_config.yaml

        # cert-manager
        CERT_MANAGER_KEYPAIR_FILE_PATH=./certificates/ca.key
        CERT_MANAGER_CERTIFICATE_FILE_PATH=./certificates/ca.crt
        CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG=./config/local/cert-manager/self-signing-clusterissuer.yaml
        CERT_MANAGER_FRONTEND_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local/cert-manager/frontend-edge-cloud-certificate.yaml
        CERT_MANAGER_API_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local/cert-manager/api-edge-cloud-certificate.yaml
        CERT_MANAGER_IDP_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local/cert-manager/idp-edge-cloud-certificate.yaml

        # istio
        ISTIO_GATEWAY_CONFIG=./config/local/istio/gateway.yaml
        ISTIO_VIRTUALSERVICE_FRONTEND_CONFIG=./config/local/istio/frontend-virtualservice.yaml
        ISTIO_VIRTUALSERVICE_API_CONFIG=./config/local/istio/api-virtualservice.yaml
        ISTIO_VIRTUALSERVICE_IDP_CONFIG=./config/local/istio/idp-virtualservice.yaml

        # edge-cloud
        EDGE_CLOUD_API_GATEWAY_URL="https://api.edge-cloud.com/graphql"
        EDGE_CLOUD_IDP_URL="https://idp.edge-cloud.com/auth/realms/master"
    else
        CALICO=./config/local-demo-server/calico.yaml

        # metallb
        METALLB_CONFIG=./config/local-demo-server/metallb_config.yaml

        # cert-manager
        CERT_MANAGER_LETS_ENCRYPT_STAGING_CLUSTER_ISSUER_CONFIG=./config/local-demo-server/cert-manager/lets-encrypt-staging-clusterissuer.yaml
        CERT_MANAGER_LETS_ENCRYPT_PROD_CLUSTER_ISSUER_CONFIG=./config/local-demo-server/cert-manager/lets-encrypt-prod-clusterissuer.yaml
        CERT_MANAGER_FRONTEND_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local-demo-server/cert-manager/frontend-edge-cloud-certificate.yaml
        CERT_MANAGER_API_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local-demo-server/cert-manager/api-edge-cloud-certificate.yaml
        CERT_MANAGER_IDP_EDGE_CLOUD_CERTIFICATE_CONFIG=./config/local-demo-server/cert-manager/idp-edge-cloud-certificate.yaml

        # istio
        ISTIO_GATEWAY_CONFIG=./config/local-demo-server/istio/gateway.yaml
        ISTIO_VIRTUALSERVICE_FRONTEND_CONFIG=./config/local-demo-server/istio/frontend-virtualservice.yaml
        ISTIO_VIRTUALSERVICE_API_CONFIG=./config/local-demo-server/istio/api-virtualservice.yaml
        ISTIO_VIRTUALSERVICE_IDP_CONFIG=./config/local-demo-server/istio/idp-virtualservice.yaml

        # edge-cloud
        EDGE_CLOUD_API_GATEWAY_URL="https://api-edgecloud.zapto.org/graphql"
        EDGE_CLOUD_IDP_URL="https://idp-edgecloud.zapto.org/auth/realms/master"
    fi
}

function create_and_configure_edge_namespace() {
    kubectl create namespace edge
    kubectl label namespace edge istio-injection=enabled # labeling the edge namespace to enable automatic istio sidecar injection
}

function deploy_helm() {
    kubectl create namespace metallb-system
    helm install metallb \
        stable/metallb \
        --version v0.12.0 \
        --set app-version=0.8.3 \
        -n metallb-system \
        --wait
    kubectl apply -f "$METALLB_CONFIG" -n metallb-system
}

function deploy_cert_manager() {
    kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
    kubectl create namespace cert-manager
    helm install cert-manager \
        jetstack/cert-manager \
        --version v0.12.0 \
        -n cert-manager \
        --wait

    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        kubectl create secret tls ca-key-pair --key="$CERT_MANAGER_KEYPAIR_FILE_PATH" --cert="$CERT_MANAGER_CERTIFICATE_FILE_PATH" -n cert-manager
        kubectl apply -n cert-manager -f "$CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG"
    else
        kubectl apply -n cert-manager -f "$CERT_MANAGER_LETS_ENCRYPT_STAGING_CLUSTER_ISSUER_CONFIG"
        kubectl apply -n cert-manager -f "$CERT_MANAGER_LETS_ENCRYPT_PROD_CLUSTER_ISSUER_CONFIG"
    fi
}

function deploy_istio() {
    kubectl create namespace istio-system

    helm install istio-init \
        istio.io/istio-init \
        --set app-version="1.4.2" \
        -n istio-system \
        --wait

    kubectl wait \
        --for=condition=complete \
        job/istio-init-crd-10-1.4.2 \
        job/istio-init-crd-11-1.4.2 \
        job/istio-init-crd-14-1.4.2  \
        -n istio-system

    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        helm install istio \
            istio.io/istio \
            --set app-version="1.4.2" \
            --set global.mtls.enabled=true \
            --set global.controlPlaneSecurityEnabled=true \
            --set global.configValidation=false \
            --set global.proxy.accessLogFile="/dev/stdout" \
            --set kiali.enabled=true \
            --set gateways.istio-ingressgateway.sds.enabled=true \
            --set gateways.istio-egressgateway.enabled=true \
            --set sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
            -n istio-system \
            --wait
    else
        helm install istio \
            istio.io/istio \
            --set app-version="1.4.2" \
            --set global.mtls.enabled=true \
            --set global.controlPlaneSecurityEnabled=true \
            --set global.configValidation=false \
            --set global.proxy.accessLogFile="/dev/stdout" \
            --set mixer.telemetry.enabled=false \
            --set prometheus.enabled=false \
            --set tracing.enabled=false \
            --set grafana.enabled=false \
            --set kiali.enabled=true \
            --set gateways.istio-ingressgateway.sds.enabled=true \
            --set gateways.istio-egressgateway.enabled=true \
            --set sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
            -n istio-system \
            --wait
    fi

    # deploying Kiali dashboard
    kubectl apply -f "$ISTIO_KIALI_SECRET_CONFIG"
    echo "Enter 'istioctl dashboard kiali' to access kiali dashboard"
}

function deploy_mongodb() {
    helm install mongodb \
        stable/mongodb \
        --set volumePermissions.enabled=true \
        --set usePassword=false \
        --set persistence.enabled=false \
        -n edge \
        --wait
}

function deploy_keycloak() {
    helm install keycloak codecentric/keycloak \
        --set keycloak.password=password \
        --set keycloak.persistence.deployPostgres=true \
        --set keycloak.persistence.dbVendor=postgres \
        --set postgresql.postgresPassword=password \
        -n edge \
        --wait
}

function apply_edge_cloud_config() {
    # applying istio ingress related config
    kubectl apply -n istio-system -f "$CERT_MANAGER_FRONTEND_EDGE_CLOUD_CERTIFICATE_CONFIG"
    kubectl apply -n istio-system -f "$CERT_MANAGER_API_EDGE_CLOUD_CERTIFICATE_CONFIG"
    kubectl apply -n istio-system -f "$CERT_MANAGER_IDP_EDGE_CLOUD_CERTIFICATE_CONFIG"

    kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_GATEWAY_CONFIG")
    kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_FRONTEND_CONFIG")
    kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_API_CONFIG")
    kubectl -n edge apply -f <(istioctl kube-inject -f "$ISTIO_VIRTUALSERVICE_IDP_CONFIG")
}

function deploy_calico() {
    kubectl apply -f "$DEMO_SERVER_CALICO"
}

function print_help() {
    set +x

    echo -e "Usage: $1 [command]\n"
    echo "Available Commands:"
    echo -e "\t generate_local_self_signed_certificate \n\t\t Generate new set of local self-signed certificates"
    echo -e "\t start \n\t\t Start K8s cluster"
    echo -e "\t stop \n\t\t Stop K8s cluster"
    echo -e "\t deploy_services <config config_path>\n\t\t Deploy all edge services"
    echo -e "\t remove_services \n\t\t Remove all edge services"
}

function generate_local_self_signed_certificate() {
    ./scripts/generate-certificate.sh
}

function start() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        kind create cluster --config "$KIND_CONFIG" --wait 5m # Block until control plane is ready
    else
        sudo kubeadm init --pod-network-cidr=172.16.0.0/16 --apiserver-advertise-address=192.168.1.3

        mkdir -p "$HOME"/.kube
        sudo cp /etc/kubernetes/admin.conf "$HOME"/.kube/config
        sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

        kubectl taint nodes --all node-role.kubernetes.io/master-
        kubectl apply -f "$CALICO"
    fi

    create_and_configure_edge_namespace
    deploy_helm
    deploy_cert_manager
    deploy_istio

    # deploying mongodb, make sure you deploy after istio deployment is done, so it inject sidecar for mongodb
    deploy_mongodb

    deploy_keycloak
    apply_edge_cloud_config

    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        echo "You need to make sure edge-cloud.com is added to your /etc/hosts file locally"
        echo "If you are using kind, you most likely got 172.17.255.1 as its IP address"
        echo "Add following line to your /etc/hosts file:"
        echo "172.17.255.1 edge-cloud.com"
    fi
}

function stop() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        kind delete cluster
    else
        sudo kubeadm reset
    fi
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
        deploy_a_service "$EDGE_CLOUD_SERVICES_CONFIG" "$service"
    done

    deploy_frontend_service "$EDGE_CLOUD_SERVICES_CONFIG"
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

    helm install "$2" \
        decentralized-cloud/"$2" \
        -n edge \
        --version "$helm_chart_version" \
        --set app-version="$app_version" \
        --set image.pullPolicy="Always" \
        --wait
}

function deploy_frontend_service() {
    helm_chart_version="$(jq -r '."'"frontend"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"frontend"'".app_version' < "$1")"

    echo -e "\nInstalling helm chart for frontend helm_chart_version=$helm_chart_version app_version=$app_version\n"

    helm install "frontend" decentralized-cloud/"frontend" \
        -n edge \
        --version "$helm_chart_version" \
        --set app-version="$app_version" \
        --set image.pullPolicy="Always" \
        --set pod.apiGateway.url="$EDGE_CLOUD_API_GATEWAY_URL" \
        --set pod.idp.clientAuthorityUrl="$EDGE_CLOUD_IDP_URL" \
        --set pod.idp.clientId="edge-cloud" \
        --wait
}

if [ "$ENVIRONMENT" != "" ] && [ "$ENVIRONMENT" != "LOCAL_KIND" ] && [ "$ENVIRONMENT" != "LOCAL_DEMO_SERVER" ]; then
    echo "Provided environment not supported: $ENVIRONMENT"
    exit 0
fi

set_local_variable

case $1 in
    generate_local_self_signed_certificate|start|stop|remove_services) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
    *) print_help "$0" ;;
esac
