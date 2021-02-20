from os import path
from os import remove
from config_helper import ConfigHelper
from system_helper import SystemHelper
import tempfile


class EdgeCloudHelper:
    ''' Deploy config and services for edge cloud '''

    env = ""
    filterEnvironment = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env, filterEnvironment):
        self.env = env.lower()
        self.filterEnvironment = filterEnvironment.lower()

    def deploy_config(self):
        env_to_func_mapper = {
            "local_kind": self.deploy_config_local_kind_windows,
            "local_windows": self.deploy_config_local_kind_windows,
            "azure": self.deploy_config_azure
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)()

    def deploy_config_local_kind_windows(self):
        self.deploy_config_env("local")

    def deploy_config_azure(self):
        self.deploy_config_env("azure")

    def deploy_config_env(self, env):
        environments = self.config_helper.get_environments()

        for environment in environments:
            if self.filterEnvironment != '':
                if environment['name'] != self.filterEnvironment:
                    continue

            rootPath = path.join(
                self.config_helper.get_config_root_Directory(), env, "istio")

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

            content = content.replace('consoleedgecloud9', '{prefix}consoleedgecloud9'.format(
                prefix=environment['namespace']))

            content = content.replace('console.edgecloud9', '{prefix}console.edgecloud9'.format(
                prefix=environment['url_prefix']))

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
