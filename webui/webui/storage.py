import subprocess
import os
import json

from webui.struct import Disk


def mount_config_partition():
    if not os.path.isdir('/mnt/config'):
        os.mkdir('/mnt/config')
    result = subprocess.call(['mount', 'label=config', '/mnt/config'])
    return result == 0


def get_disks():
    result = []
    command = ['lsblk', '--nodeps', '-b', '-o', 'NAME,ROTA,HCTL,TRAN,SIZE,RM,MODEL,SERIAL,TYPE,FSTYPE', '--json']
    output = subprocess.check_output(command).decode()
    output = json.loads(output)['blockdevices']
    for blkdev in output:
        if blkdev['rm'] == '1':
            continue

        if blkdev['type'] == '':
            continue

        device = Disk()
        device.dev = blkdev['name']
        device.type = 'HDD' if blkdev['rota'] == '1' else 'SSD'
        device.transport = blkdev['tran']

        if device.transport == 'sata':
            device.port = blkdev['hctl'].split(':')[0]

        device.model = blkdev['model']
        device.serial = blkdev['serial']
        device.size = int(blkdev['size'])

        result.append(device)
    return result


if __name__ == '__main__':
    print(get_disks())
