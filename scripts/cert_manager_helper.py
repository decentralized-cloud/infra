from os import path
from system_helper import SystemHelper


class CertManagerHelper:
    ''' Simplify deploying Cert Manager '''

    system_helper = SystemHelper()

    def deploy(self):
        self.system_helper.execute(
            "helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.1.0 --set installCRDs=true --wait")
