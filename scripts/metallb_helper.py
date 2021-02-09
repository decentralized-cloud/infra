import yaml
from os import path
from os import remove
from config_helper import ConfigHelper
from system_helper import SystemHelper
from k8s_helper import K8SHelper
import tempfile


class MetallbHelper:
    ''' Simplify deploying metallb '''

    filterEnvironment = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, filterEnvironment):
        self.filterEnvironment = filterEnvironment.lower()

    def deploy(self):
        self.system_helper.execute(
            "helm install metallb bitnami/metallb -n metallb-system --wait")

        ip_range = K8SHelper(self.filterEnvironment).get_ip_range()

        config_file_path = path.join(
            self.config_helper.get_config_root_Directory(), "common", "metallb_config.yaml")

        tmp_file_name = path.join(tempfile._get_default_tempdir(), next(
            tempfile._get_candidate_names()))

        with open(config_file_path) as file:
            yaml_config = yaml.full_load(file)
            yaml_config["data"]["config"] = "address-pools:\n- name: default\n  protocol: layer2\n  addresses:\n  - {from_ip}-{to_ip}\n".format(
                from_ip=ip_range[0], to_ip=ip_range[1])

            tmp_config_file = open(tmp_file_name, "w")
            tmp_config_file.write(yaml.dump(yaml_config))
            tmp_config_file.close()

        self.system_helper.execute(
            "kubectl apply -f \"{config_file}\" -n metallb-system".format(config_file=tmp_file_name))

        remove(tmp_file_name)
