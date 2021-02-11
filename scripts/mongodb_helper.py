from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class MongoDBHelper:
    ''' Simplify deploying MongoDB '''

    filterEnvironment = ""
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def __init__(self, filterEnvironment):
        self.filterEnvironment = filterEnvironment.lower()

    def deploy(self):
        environments = self.config_helper.get_environments()

        for environment in environments:
            if self.filterEnvironment != '':
                if environment['name'] != self.filterEnvironment:
                    continue

            self.system_helper.execute(
                ("helm upgrade --install mongodb bitnami/mongodb "
                 "--set volumePermissions.enabled=true "
                 "--set auth.enabled=false "
                 "--set persistence.enabled=false "
                 "-n {namespace} --wait".format(namespace=environment['namespace'])))
