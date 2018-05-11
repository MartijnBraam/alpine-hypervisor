import subprocess
import os


def mount_config_partition():
    if not os.path.isdir('/mnt/config'):
        os.mkdir('/mnt/config')
    result = subprocess.call(['mount', 'label=config', '/mnt/config'])
    return result == 0
