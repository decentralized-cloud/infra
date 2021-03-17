#!/usr/bin/env bash

set -e
set -x

current_directory=$(dirname "$0")
cd "$current_directory"/..

# Common Config
EDGE_CLOUD_SERVICES_CONFIG=./config/common/edge-cloud/services.json

readonly EDGE_SERVICES="user project edge-cluster api-gateway"

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
                        
                        deploy_console_service "$1"
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
    
    deploy_console_service "$EDGE_CLOUD_SERVICES_CONFIG"
}

function remove_services() {
    for service in $EDGE_SERVICES; do
        helm uninstall "$service" -n dev || true
    done
    
    helm uninstall "console" -n dev || true
}

function deploy_a_service() {
    helm_chart_version="$(jq -r '."'"$2"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"$2"'".app_version' < "$1")"
    image_pull_policy="$(jq -r '."'"$2"'".image_pull_policy' < "$1")"
    
    echo -e "\nInstalling helm chart for $2 helm_chart_version=$helm_chart_version app_version=$app_version\n"
    
    helm upgrade --install "$2" \
    decentralized-cloud/"$2" \
    --namespace dev \
    --recreate-pods \
    --version "$helm_chart_version" \
    --set image.tag="$app_version" \
    --set image.pullPolicy=$image_pull_policy \
    --set pod.idp.jwksURL="https://edgecloud.au.auth0.com/.well-known/jwks.json"
}

function deploy_console_service() {
    helm_chart_version="$(jq -r '."'"console"'".helm_chart_version' < "$1")"
    app_version="$(jq -r '."'"console"'".app_version' < "$1")"
    image_pull_policy="$(jq -r '."'"console"'".image_pull_policy' < "$1")"
    
    echo -e "\nInstalling helm chart for console helm_chart_version=$helm_chart_version app_version=$app_version\n"
    
    helm upgrade --install "console" \
    decentralized-cloud/"console" \
    --namespace dev \
    --recreate-pods \
    --version "$helm_chart_version" \
    --set image.tag="$app_version" \
    --set image.pullPolicy=$image_pull_policy \
    --set pod.apiGateway.url="https://api.edgecloud.com/graphql" \
    --set pod.idp.auth0Domain="edgecloud.au.auth0.com" \
    --set pod.idp.auth0ClientId="01ktnKPjGdkkerNdtDWQM7gCGuXGUBT9"
}

function print_help() {
    set +x
    
    echo -e "Usage: $1 [command]\n"
    echo "Available Commands:"
    echo -e "\t deploy_services <config config_path>\n\t\t Deploy all edge services"
    echo -e "\t remove_services \n\t\t Remove all edge services"
}

case $1 in
    remove_services) "$1" ;;
    deploy_services) "$1" "${@:2}" ;;
    *) print_help "$0" ;;
esac
