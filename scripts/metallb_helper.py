from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class MetallbHelper:
    ''' Simplify deploying metallb '''

    env = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, env):
        self.env = env.lower()

    def deploy(self):
        env_to_func_mapper = {
            "local_kind": self.deploy_local_kind
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        self.system_helper.execute(
            "helm install metallb bitnami/metallb -n metallb-system --wait")

        env_to_func_mapper.get(self.env)()

    def deploy_local_kind(self):
        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\" -n metallb-system".format(config_file=path.join(
                self.config_helper.get_config_root_Directory(), "local", "metallb_config.yaml")))
