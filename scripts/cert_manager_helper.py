from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class CertManagerHelper:
    ''' Simplify deploying Cert Manager '''

    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def deploy(self):
        self.system_helper.execute(
            "helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.1.0 --set installCRDs=true --wait")

        certificates_directory = path.join(
            path.dirname(__file__), "..", "certificates")

        self.system_helper.execute(
            "kubectl create -n cert-manager secret tls ca-key-pair --key=\"{keypair_file}\" --cert=\"{certificate_file}\"".format(
                keypair_file=path.join(
                    certificates_directory, "ca.key"), certificate_file=path.join(
                    certificates_directory, "ca.crt")))

        self.system_helper.execute(
            "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "common", "cert-manager", "clusterissuers.yaml")))
