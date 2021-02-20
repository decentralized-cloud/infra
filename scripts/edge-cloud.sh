#!/usr/bin/env bash

set -e
set -x

current_directory=$(dirname "$0")
cd "$current_directory"/..

# Common Config
ISTIO_KIALI_SECRET_CONFIG=./config/common/istio/kiali_secret.yaml
EDGE_CLOUD_SERVICES_CONFIG=./config/common/edge-cloud/services.json

K8S_DASHBOARD_SERVICE_ACCOUNT_CONFIG=./config/common/k8s-dashboard/service-account.yaml
K8S_DASHBOARD_ROLE_CONFIG=./config/common/k8s-dashboard/role.yaml

declare -a DockerImagesToPreload=(
    "kubernetesui/metrics-scraper:v1.0.4"
    "kubernetesui/dashboard:v2.0.0"
    
    "docker.io/bitnami/metallb-controller:0.9.5-debian-10-r62"
    "docker.io/bitnami/metallb-speaker:0.9.5-debian-10-r67"
    
    "quay.io/jetstack/cert-manager-controller:v1.1.0"
    "quay.io/jetstack/cert-manager-cainjector:v1.1.0"
    "quay.io/jetstack/cert-manager-webhook:v1.1.0"
    
    "docker.io/istio/operator:1.7.6"
    "docker.io/istio/proxyv2:1.7.6"
    "docker.io/istio/pilot:1.7.6"
    "quay.io/kiali/kiali:v1.26"
    "openzipkin/zipkin-slim:2.21.0"
    "grafana/grafana:7.2.1"
    "docker.io/jaegertracing/all-in-one:1.20"
    "jimmidyson/configmap-reload:v0.4.0"
    "prom/prometheus:v2.21.0"
    
    "docker.io/bitnami/mongodb:4.4.3-debian-10-r0"
    
    "rancher/k3s:v1.20.0-k3s2"
)

function set_local_variable() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        # metallb
        METALLB_CONFIG=./config/local/metallb_config.yaml
        
        # cert-manager
        CERT_MANAGER_KEYPAIR_FILE_PATH=./certificates/ca.key
        CERT_MANAGER_CERTIFICATE_FILE_PATH=./certificates/ca.crt
        CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG=./config/local/cert-manager/self-signing-clusterissuer.yaml
        ISTIO_CERTIFICATES_CONFIG=./config/local/cert-manager/certificates.yaml
        
        # istio
        ISTIO_GATEWAY_HTTPS_CONFIG=./config/local/istio/gateway-https.yaml
        ISTIO_VIRTUALSERVICES_HTTPS_CONFIG=./config/local/istio/virtualservices-https.yaml
        
        # edge-cloud
        EDGE_CLOUD_API_GATEWAY_URL="https://api.devedgecloud.com/graphql"
        EDGE_CLOUD_AUTH0_DOMAIN="dev-lyrnhma6.auth0.com"
        EDGE_CLOUD_AUTH0_CLIENT_ID="3o25jdb1W3xG1UCkI2Z7WzbBdPjZWRoW"
    fi
    
    if [ "$ENVIRONMENT" = "LOCAL_DEMO_SERVER" ]; then
        DEMO_SERVER_CALICO=./config/local-demo-server/calico.yaml
        
        # metallb
        METALLB_CONFIG=./config/local-demo-server/metallb_config.yaml
        
        # cert-manager
        CERT_MANAGER_LETSENCRYPT_CLUSTER_ISSUER_CONFIG=./config/local-demo-server/cert-manager/letsencrypt-clusterissuer.yaml
        ISTIO_CERTIFICATES_CONFIG=./config/local-demo-server/cert-manager/certificates.yaml
        
        # istio
        ISTIO_GATEWAY_HTTP_CONFIG=./config/local-demo-server/istio/gateway-http.yaml
        ISTIO_GATEWAY_HTTPS_CONFIG=./config/local-demo-server/istio/gateway-https.yaml
        ISTIO_VIRTUALSERVICES_HTTP_CONFIG=./config/local-demo-server/istio/virtualservices-http.yaml
        ISTIO_VIRTUALSERVICES_HTTPS_CONFIG=./config/local-demo-server/istio/virtualservices-https.yaml
        
        # edge-cloud
        EDGE_CLOUD_API_GATEWAY_URL="https://api-edgecloud.zapto.org/graphql"
    fi
}

function pull_latest_docker_images() {
    for dockerImage in "${DockerImagesToPreload[@]}"; do
        docker pull "$dockerImage"
    done
}

function setup_cluster() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        KIND_CONFIG="${KIND_CONFIG:-./config/local/kind_config.yaml}"
        kind create cluster --config "$KIND_CONFIG" --wait 5m # Block until control plane is ready
        
        for dockerImage in "${DockerImagesToPreload[@]}"; do
            kind load docker-image "$dockerImage"
        done
    else
        sudo kubeadm init --pod-network-cidr=172.16.0.0/16 --apiserver-advertise-address=192.168.1.3
        
        mkdir -p "$HOME"/.kube
        sudo cp /etc/kubernetes/admin.conf "$HOME"/.kube/config
        sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
        
        kubectl taint nodes --all node-role.kubernetes.io/master-
        deploy_calico
    fi
}

function deploy_calico() {
    kubectl apply -f "$DEMO_SERVER_CALICO"
}

function create_and_configure_namespaces() {
    kubectl create namespace metallb-system
    kubectl create namespace cert-manager
    kubectl create namespace istio-system
    kubectl create namespace edge
    
    kubectl label namespace edge istio-injection=enabled
}

function deploy_metallb() {
    helm upgrade --install metallb \
    bitnami/metallb \
    -n metallb-system \
    --wait
    kubectl apply -f "$METALLB_CONFIG" -n metallb-system
}

function deploy_kubernetes_dashboard() {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
    kubectl apply -f "$K8S_DASHBOARD_SERVICE_ACCOUNT_CONFIG"
    kubectl apply -f "$K8S_DASHBOARD_ROLE_CONFIG"
    kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
}

function deploy_cert_manager() {
    helm upgrade --install \
    cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version v1.1.0 \
    --set installCRDs=true \
    --wait
}

function deploy_istio() {
    istioctl operator init
    kubectl apply -f ./config/local/istio/istio.yaml
}

function deploy_istio_addons() {
    kubectl apply -f ./istio/samples/addons/grafana.yaml
    kubectl apply -f ./istio/samples/addons/jaeger.yaml
    kubectl apply -f ./istio/samples/addons/prometheus.yaml
    kubectl apply -f ./istio/samples/addons/kiali.yaml
    kubectl apply -f ./istio/samples/addons/extras/zipkin.yaml
    
    echo "Enter 'istioctl dashboard kiali' to access kiali dashboard"
}

function deploy_mongodb() {
    helm upgrade --install mongodb \
    bitnami/mongodb \
    --set volumePermissions.enabled=true \
    --set auth.enabled=false \
    --set persistence.enabled=false \
    -n edge \
    --wait
}

function apply_edge_cloud_config() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        kubectl create -n cert-manager secret tls ca-key-pair --key="$CERT_MANAGER_KEYPAIR_FILE_PATH" --cert="$CERT_MANAGER_CERTIFICATE_FILE_PATH"
        kubectl apply -n cert-manager -f "$CERT_MANAGER_SELF_SIGNING_CLUSTER_ISSUER_CONFIG"
    else
        kubectl apply -n edge -f "$CERT_MANAGER_LETSENCRYPT_CLUSTER_ISSUER_CONFIG"
    fi
    
    if [ "$ENVIRONMENT" = "LOCAL_DEMO_SERVER" ]; then
        kubectl apply -n edge -f "$ISTIO_CERTIFICATES_CONFIG"
    else
        kubectl apply -n istio-system -f "$ISTIO_CERTIFICATES_CONFIG"
    fi
    
    if [ "$ENVIRONMENT" = "LOCAL_DEMO_SERVER" ]; then
        istioctl kube-inject -f "$ISTIO_GATEWAY_HTTP_CONFIG" | kubectl apply -n edge -f -
        istioctl kube-inject -f "$ISTIO_VIRTUALSERVICES_HTTP_CONFIG" | kubectl apply -n edge -f -
    fi
    
    istioctl kube-inject -f "$ISTIO_GATEWAY_HTTPS_CONFIG" | kubectl apply -n edge -f -
    istioctl kube-inject -f "$ISTIO_VIRTUALSERVICES_HTTPS_CONFIG" | kubectl apply -n edge -f -
}

function print_help() {
    set +x
    
    echo -e "Usage: $1 [command]\n"
    echo "Available Commands:"
    echo -e "\t pull_latest_docker_images \n\t\t Pull down latest required docker images"
    echo -e "\t start \n\t\t Start K8s cluster"
    echo -e "\t stop \n\t\t Stop K8s cluster"
    echo -e "\t deploy_services <config config_path>\n\t\t Deploy all edge services"
    echo -e "\t remove_services \n\t\t Remove all edge services"
    echo -e "\t deploy_istio_addons \n\t\t Deploy istio addons"
}

function start() {
    setup_cluster
    create_and_configure_namespaces
    deploy_metallb
    deploy_kubernetes_dashboard
    deploy_cert_manager
    deploy_istio
    
    # all other services must be deployed after istio is successfully deployed to ensure it inject sidecar for them all
    deploy_mongodb
    apply_edge_cloud_config
    
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        echo "You need to make sure edge-cloud.com is added to your /etc/hosts file locally"
        echo "If you are using kind, you most likely got 172.18.255.1 as its IP address"
        echo "Add following line to your /etc/hosts file:"
        echo "172.18.255.1 edge-cloud.com"
    fi
}

function stop() {
    if [ "$ENVIRONMENT" = "" ] || [ "$ENVIRONMENT" = "LOCAL_KIND" ]; then
        kind delete cluster
    else
        sudo kubeadm reset
    fi
}

readonly EDGE_SERVICES="project api-gateway edge-cluster"

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
        helm uninstall "$service" -n dev || true
    done
    
    helm uninstall "frontend" -n dev || true
}

function deploy_a_service() {
    helm_chart_version="$(jq -r '."'"$2"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"$2"'".app_version' < "$1")"
    image_pull_policy="$(jq -r '."'"$2"'".image_pull_policy' < "$1")"
    
    echo -e "\nInstalling helm chart for $2 helm_chart_version=$helm_chart_version app_version=$app_version\n"
    
    helm upgrade --install "$2" \
    decentralized-cloud/"$2" \
    -n dev \
    --version "$helm_chart_version" \
    --set image.tag="$app_version" \
    --set image.pullPolicy=$image_pull_policy
}

function deploy_frontend_service() {
    helm_chart_version="$(jq -r '."'"frontend"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"frontend"'".app_version' < "$1")"
    image_pull_policy="$(jq -r '."'"frontend"'".image_pull_policy' < "$1")"
    
    echo -e "\nInstalling helm chart for frontend helm_chart_version=$helm_chart_version app_version=$app_version\n"
    
    helm upgrade --install "frontend" decentralized-cloud/"frontend" \
    -n dev \
    --version "$helm_chart_version" \
    --set image.tag="$app_version" \
    --set image.pullPolicy=$image_pull_policy \
    --set pod.apiGateway.url="$EDGE_CLOUD_API_GATEWAY_URL" \
    --set pod.idp.auth0Domain="$EDGE_CLOUD_AUTH0_DOMAIN" \
    --set pod.idp.auth0ClientId="$EDGE_CLOUD_AUTH0_CLIENT_ID"
}

if [ "$ENVIRONMENT" != "" ] && [ "$ENVIRONMENT" != "LOCAL_KIND" ] && [ "$ENVIRONMENT" != "LOCAL_DEMO_SERVER" ]; then
    echo "Provided environment not supported: $ENVIRONMENT"
    exit 0
fi

set_local_variable

case $1 in
    pull_latest_docker_images|start|stop|remove_services|deploy_istio_addons) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
    *) print_help "$0" ;;
esac
