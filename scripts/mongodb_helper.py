from os import path
from system_helper import SystemHelper


class MongoDBHelper:
    ''' Simplify deploying MongoDB '''

    system_helper = SystemHelper()

    def deploy(self):
        self.system_helper.execute(
            "helm install mongodb bitnami/mongodb --set volumePermissions.enabled=true --set auth.enabled=false --set persistence.enabled=false -n edge --wait")
