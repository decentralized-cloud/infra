from kind_cluster import KindCluster
from k8s_helper import K8SHelper
from metallb_helper import MetallbHelper
from k8s_dashboard_helper import K8SDashboardHelper
from cert_manager_helper import CertManagerHelper
from istio_helper import IstioHelper
from mongodb_helper import MongoDBHelper
from edge_cloud_helper import EdgeCloudHelper


class ClusterHelper:
    ''' Simplify working with different type cluster such as those created by Kind '''

    env = ""
    kind_cluster = KindCluster()

    def __init__(self, env):
        self.env = env.lower()

    def start(self, preload_images):
        env_to_start_func_mapper = {
            "local_kind": self.start_kind
        }

        if not self.env in env_to_start_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_start_func_mapper.get(self.env)(preload_images)
        K8SHelper().create_namespaces()
        MetallbHelper(self.env).deploy()
        K8SDashboardHelper().deploy()
        CertManagerHelper().deploy()
        IstioHelper().deploy()
        MongoDBHelper().deploy()
        EdgeCloudHelper(self.env).deploy_config()

        env_to_display_confirmation_func_mapper = {
            "local_kind": self.display_confirmation_kind
        }

        if not self.env in env_to_display_confirmation_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_display_confirmation_func_mapper.get(self.env)()

    def stop(self):
        env_to_func_mapper = {
            "local_kind": self.stop_kind
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)()

    def start_kind(self, preload_images):
        self.kind_cluster.start(preload_images)

    def stop_kind(self):
        self.kind_cluster.stop()

    def display_confirmation_kind(self):
        print()
        print("************************************************************************************")
        print("You need to make sure edge-cloud.com is added to your /etc/hosts file locally")
        print("If you are using kind, you most likely got 172.18.255.1 as its IP address")
        print("Add following line to your /etc/hosts file:")
        print("172.18.255.1 edge-cloud.com")
        print("************************************************************************************")
        print()
