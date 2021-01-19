from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper

class K8SHelper:
    ''' Wraps kind command line '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def create_namespaces(self):
            namespaces = self.config_helper.get_all_namespaces()

            for namespace in namespaces:
                self.system_helper.execute("kubectl create namespace {name}".format(name=namespace['name']))

                for label in namespace['labels']:
                    self.system_helper.execute("kubectl label namespace {name} {label}".format(name=namespace['name'], label=label))

