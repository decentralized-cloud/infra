import json
from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class K8SHelper:
    ''' Provide different functionality specific to K8S cluster that are required to deploy different resources '''

    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def create_namespaces(self):
        namespaces = self.get_all_namespaces()

        for namespace in namespaces:
            self.system_helper.execute(
                "kubectl create namespace {name}".format(name=namespace['name']))

            for label in namespace['labels']:
                self.system_helper.execute("kubectl label namespace {name} {label}".format(
                    name=namespace['name'], label=label))

    def get_all_namespaces(self):
        with open(path.join(
                self.config_helper.get_config_root_Directory(), "common", "k8s-namespaces.json")) as f:
            return json.load(f)
