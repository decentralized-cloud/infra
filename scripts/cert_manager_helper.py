from os import path
from os import remove
from os import environ
from config_helper import ConfigHelper
from system_helper import SystemHelper
import tempfile


class CertManagerHelper:
    ''' Simplify deploying Cert Manager '''

    env = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env):
        self.env = env.lower()

    def deploy(self):
        self.system_helper.execute(
            "helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.2.0 --set installCRDs=true --wait")

        if self.env == "local_kind" or self.env == 'local_windows':
            certificates_directory = self.config_helper.get_certificates_directory()

            self.system_helper.execute(
                "kubectl create -n istio-system secret tls ca-key-pair --key=\"{keypair_file}\" --cert=\"{certificate_file}\"".format(
                    keypair_file=path.join(
                        certificates_directory, "ca.key"), certificate_file=path.join(
                        certificates_directory, "ca.crt")))

            self.system_helper.execute(
                "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=path.join(
                    self.config_helper.get_config_root_directory(), "common", "cert-manager", "self-signed-clusterissuers.yaml")))

        if self.env == "remote":
            godaddy = path.join(
                path.dirname(__file__), "..", "godaddy-webhook", "deploy", "godaddy-webhook")

            self.system_helper.execute(
                "helm upgrade --install godaddy-webhook --namespace cert-manager {godaddy} --wait".format(godaddy=godaddy))

            apikey_secret = environ["GODADDY_API_SECRET"]
            tmp_file_name = path.join(tempfile._get_default_tempdir(), next(
                tempfile._get_candidate_names()))

            with open(
                path.join(
                    self.config_helper.get_config_root_directory(), "common", "cert-manager", "godaddy-clusterissuers.yaml")) as file:
                content = file.read()
                content = content.replace('<key:secret>', apikey_secret)
                tmp_config_file = open(tmp_file_name, "w")
                tmp_config_file.write(content)
                tmp_config_file.close()

                self.system_helper.execute(
                    "kubectl apply -n istio-system -f \"{config_file}\"".format(config_file=tmp_file_name))

                remove(tmp_file_name)
