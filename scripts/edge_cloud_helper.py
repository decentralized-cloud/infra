from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class EdgeCloudHelper:
    ''' Deploy config and services for edge cloud '''

    env = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env):
        self.env = env.lower()

    def deploy_config(self):
        env_to_func_mapper = {
            "local_kind": self.deploy_config_local_kind_windows,
            "local_windows": self.deploy_config_local_kind_windows,
            "local_windows": self.deploy_config_azure
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)()

    def deploy_config_local_kind_windows(self):
        self.system_helper.execute(
            "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "local", "istio", "certificates.yaml")))

        self.system_helper.execute(
            "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n edge -f -".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "local", "istio", "gateway-https.yaml")))

        self.system_helper.execute(
            "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n edge -f -".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "local", "istio", "virtualservices-https.yaml")))

    def deploy_config_azure(self):
        self.system_helper.execute(
            "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "azure", "istio", "certificates.yaml")))

        self.system_helper.execute(
            "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n edge -f -".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "azure", "istio", "gateway-https.yaml")))

        self.system_helper.execute(
            "istioctl kube-inject -f \"{config_file}\" | kubectl apply -n edge -f -".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "azure", "istio", "virtualservices-https.yaml")))
