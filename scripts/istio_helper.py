from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class IstioHelper:
    ''' Simplify deploying Istio '''

    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def deploy(self):
        self.system_helper.execute(
            "istioctl operator init")

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "local", "istio", "istio.yaml")))

    def deploy_addons(self):
        istio_addons_config_directory = path.join(
            path.dirname(__file__), "..", "istio", "samples", "addons")

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                istio_addons_config_directory, "grafana.yaml")))

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                istio_addons_config_directory, "jaeger.yaml")))

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                istio_addons_config_directory, "prometheus.yaml")))

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                istio_addons_config_directory, "kiali.yaml")))

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\"".format(config_file=path.join(
                istio_addons_config_directory, "extras", "zipkin.yaml")))

        print("Enter 'istioctl dashboard kiali' to access kiali dashboard")
