import time

from sys_metric.model.metric_base import BasePsEntity


class CpuEntity(BasePsEntity):

    def get_usage_percent(self):
        while True:
            cpu_usage = self.entity.cpu_percent()
            if cpu_usage == 0:
                time.sleep(1)
            else:
                return cpu_usage
