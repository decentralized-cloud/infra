from kind_cluster import KindCluster


class ClusterHelper:
    ''' Simplify working with different type cluster such as those created by Kind '''

    env = ""
    kind_cluster = KindCluster()

    def __init__(self, env):
        self.env = env.lower()

    def start(self, preload_images):
        env_to_func_mapper = {
            "local_kind": self.start_kind
        }

        if not self.env in env_to_func_mapper:
            raise Exception(
                "Environment '{env}' is not supported".format(env=self.env))

        env_to_func_mapper.get(self.env)(preload_images)

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
