import json
from os import path
from system_helper import SystemHelper


class K8SHelper:
    ''' Provide different functionality specific to K8S cluster that are required to deploy different resources '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")
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
        config_file = path.join(
            self.config_directory_path, "common", "k8s-namespaces.json")

        if not path.exists(config_file):
            raise Exception(f'Config file "{config_file}" does not exist')

        with open(config_file) as f:
            return json.load(f)
