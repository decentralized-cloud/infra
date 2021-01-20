from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class K8SDashboardHelper:
    ''' Simplify deploying K8S dashboard '''

    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def deploy(self):
        self.system_helper.execute(
            "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml")

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "common", "k8s-dashboard", "service-account.yaml")))

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "common", "k8s-dashboard", "role.yaml")))

        self.system_helper.execute(
            "kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')")
