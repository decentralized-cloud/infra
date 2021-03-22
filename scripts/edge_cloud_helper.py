from os import path
from os import remove
from config_helper import ConfigHelper
from system_helper import SystemHelper
import tempfile


class EdgeCloudHelper:
    ''' Deploy config and services for edge cloud '''

    env = ""
    filterEnvironment = ""
    services = {}
    environments = {}
    jwksURL = "https://edgecloud.au.auth0.com/.well-known/jwks.json"
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env, filterEnvironment):
        self.env = env.lower()
        self.filterEnvironment = filterEnvironment.lower()
        self.services = self.config_helper.get_services()
        self.environments = self.config_helper.get_environments()

    def deploy_config(self):
        env_to_func_mapper = {
            "local_kind": self.deploy_config_local_kind_windows,
            "local_windows": self.deploy_config_local_kind_windows,
            "remote": self.deploy_config_remote
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)()

    def deploy_services(self, services):
        if "user" in services:
            self.deploy_helm_services('user')

        if "project" in services:
            self.deploy_helm_services('project')

        if "edge-cluster" in services:
            self.deploy_helm_services('edge-cluster')

        if "api-gateway" in services:
            self.deploy_helm_services('api-gateway')

        if "console" in services:
            self.deploy_console()

    def remove_services(self, services):
        if "user" in services:
            self.remove_helm_services('user')

        if "project" in services:
            self.remove_helm_services('project')

        if "edge-cluster" in services:
            self.remove_helm_services('edge-cluster')

        if "api-gateway" in services:
            self.remove_helm_services('api-gateway')

        if "console" in services:
            self.remove_helm_services('console')

    def deploy_config_local_kind_windows(self):
        self.deploy_config_env("local")

    def deploy_config_remote(self):
        self.deploy_config_env("remote")

    def deploy_config_env(self, env):
        for environment in self.environments:
            if self.filterEnvironment != '':
                if environment['name'] != self.filterEnvironment:
                    continue

            rootPath = path.join(
                self.config_helper.get_config_root_directory(), env, "istio")

            # Creating Certificates
            tmp_config_file = self.transformConfigFileContent(
                path.join(rootPath, "certificates.yaml"), environment)
            self.system_helper.execute(
                "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=tmp_config_file))

            remove(tmp_config_file)

            # Creating Gateways
            tmp_config_file = self.transformConfigFileContent(
                path.join(rootPath, "gateways.yaml"), environment)

            self.system_helper.execute(
                "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n {namespace} -f -".format(config_file=tmp_config_file, namespace=environment['namespace']))
            remove(tmp_config_file)

            # Creating Virtual Services
            tmp_config_file = self.transformConfigFileContent(
                path.join(rootPath, "virtualservices.yaml"), environment)

            self.system_helper.execute(
                "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n {namespace} -f -".format(config_file=tmp_config_file, namespace=environment['namespace']))
            remove(tmp_config_file)

    def transformConfigFileContent(self, config_file_path, environment):
        tmp_file_name = path.join(tempfile._get_default_tempdir(), next(
            tempfile._get_candidate_names()))

        with open(config_file_path) as file:
            content = file.read()

            content = content.replace('apiedgecloud9', '{prefix}apiedgecloud9'.format(
                prefix=environment['namespace']))

            content = content.replace('api.edgecloud9', '{prefix}api.edgecloud9'.format(
                prefix=environment['url_prefix']))

            content = content.replace('.edge.svc', '.{namespace}.svc'.format(
                namespace=environment['namespace']))

            tmp_config_file = open(tmp_file_name, "w")
            tmp_config_file.write(content)
            tmp_config_file.close()

        return tmp_file_name

    def deploy_helm_services(self, name):
        setting = self.services[name]

        self.system_helper.execute(
            '''helm upgrade --install \\
                {name} \\
                decentralized-cloud/{name} \\
                --namespace dev \\
                --recreate-pods \\
                --version {helm_chart_version} \\
                --set image.tag={app_version} \\
                --set image.pullPolicy={image_pull_policy} \\
                --set pod.idp.jwksURL={jwksURL} \\
                --set pod.k3s.dockerImage={k3sDockerImage}'''.format(
                name=name,
                helm_chart_version=setting['helm_chart_version'],
                app_version=setting['app_version'],
                image_pull_policy=setting['image_pull_policy'],
                jwksURL=self.jwksURL,
                k3sDockerImage='rancher/k3s:v1.20.4-k3s1'))

    def deploy_console(self):
        setting = self.services['console']

        self.system_helper.execute(
            '''helm upgrade --install \\
                console \\
                decentralized-cloud/console \\
                --namespace dev \\
                --recreate-pods \\
                --version {helm_chart_version} \\
                --set image.tag={app_version} \\
                --set image.pullPolicy={image_pull_policy} \\
                --set pod.apiGateway.url="https://api.edgecloud.com/graphql" \\
                --set pod.idp.auth0Domain="edgecloud.au.auth0.com" \\
                --set pod.idp.auth0ClientId="01ktnKPjGdkkerNdtDWQM7gCGuXGUBT9"'''.format(
                helm_chart_version=setting['helm_chart_version'],
                app_version=setting['app_version'],
                image_pull_policy=setting['image_pull_policy']))

    def remove_helm_services(self, name):
        self.system_helper.execute(
            '''helm uninstall \\
                {name} \\
                --namespace dev'''.format(
                name=name))
