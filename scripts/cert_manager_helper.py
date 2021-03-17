from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class CertManagerHelper:
    ''' Simplify deploying Cert Manager '''

    env = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env):
        self.env = env.lower()

    def deploy(self):
        self.system_helper.execute(
            "helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.1.0 --set installCRDs=true --wait")

        if self.env == "local_kind" or self.env == 'local_windows':
            certificates_directory = path.join(
                path.dirname(__file__), "..", "certificates")

            self.system_helper.execute(
                "kubectl create -n istio-system secret tls ca-key-pair --key=\"{keypair_file}\" --cert=\"{certificate_file}\"".format(
                    keypair_file=path.join(
                        certificates_directory, "ca.key"), certificate_file=path.join(
                        certificates_directory, "ca.crt")))

            self.system_helper.execute(
                "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                    self.config_helper.get_config_root_Directory(), "common", "cert-manager", "self-signed-clusterissuers.yaml")))

        if self.env == "remote":
            godaddy = path.join(
                path.dirname(__file__), "..", "godaddy-webhook", "deploy", "godaddy-webhook")

            self.system_helper.execute(
                "helm upgrade --install godaddy-webhook --namespace cert-manager {godaddy} --wait".format(godaddy=godaddy))

            self.system_helper.execute(
                "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                    self.config_helper.get_config_root_Directory(), "common", "cert-manager", "godaddy-clusterissuers.yaml")))
