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
    filterEnvironment = ""
    kind_cluster = KindCluster()

    def __init__(self, env, filterEnvironment):
        self.env = env.lower()
        self.filterEnvironment = filterEnvironment.lower()

    def start(self, preload_images):
        env_to_start_func_mapper = {
            "local_kind": self.start_local_kind,
            "local_windows": self.start_local_windows,
            "remote": self.start_remote
        }

        if not self.env in env_to_start_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_start_func_mapper.get(self.env)(preload_images)
        K8SHelper(self.filterEnvironment).create_namespaces()

        env_to_deploy_metallb_func_mapper = {
            "local_kind": self.deploy_metallb_local_kind,
            "local_windows": self.deploy_metallb_local_windows,
            "remote": self.deploy_metallb_remote
        }

        if not self.env in env_to_deploy_metallb_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_deploy_metallb_func_mapper.get(self.env)()

        K8SDashboardHelper().deploy()
        CertManagerHelper(self.env).deploy()
        IstioHelper().deploy()
        MongoDBHelper(self.filterEnvironment).deploy()
        EdgeCloudHelper(self.env, self.filterEnvironment).deploy_config()

        env_to_display_confirmation_func_mapper = {
            "local_kind": self.display_confirmation_local_kind,
            "local_windows": self.display_confirmation_local_windows,
            "remote": self.display_confirmation_remote
        }

        if not self.env in env_to_display_confirmation_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_display_confirmation_func_mapper.get(self.env)()

    def stop(self):
        env_to_func_mapper = {
            "local_kind": self.stop_local_kind,
            "local_windows": self.stop_local_windows,
            "remote": self.stop_remote
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)()

    def start_local_kind(self, preload_images):
        self.kind_cluster.start(preload_images)

    def deploy_metallb_local_kind(self):
        MetallbHelper(self.filterEnvironment).deploy()

    def stop_local_kind(self):
        self.kind_cluster.stop()

    def display_confirmation_local_kind(self):
        ingress_ip = K8SHelper(self.filterEnvironment).get_ip_range()[0]

        print()
        print("************************************************************************************")
        print(
            "You need to make sure edgecloud.com is added to your /etc/hosts file locally")
        print("If you are using kind, you most likely got {ingress_ip} as its IP address".format(
            ingress_ip=ingress_ip))
        print("Add following line to your /etc/hosts file:")
        print("{ingress_ip} edgecloud.com".format(ingress_ip=ingress_ip))
        print("{ingress_ip} api.edgecloud.com".format(ingress_ip=ingress_ip))
        print("************************************************************************************")
        print()

    def start_local_windows(self, preload_images):
        return

    def deploy_metallb_local_windows(self):
        return

    def stop_local_windows(self):
        return

    def display_confirmation_local_windows(self):
        return

    def start_remote(self, preload_images):
        return

    def deploy_metallb_remote(self):
        return

    def stop_remote(self):
        return

    def display_confirmation_remote(self):
        return
