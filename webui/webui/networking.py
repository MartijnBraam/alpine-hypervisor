import subprocess
import os


def setup_from_config():
    refresh_hostname()


def setup_all_dhcp():
    for interface in _get_interface_names():
        subprocess.call(['ip', 'link', 'set', 'dev', interface, 'up'])
        subprocess.call(['udhcpc', '-i', interface, '-n', '-q', '-f'])


def refresh_hostname():
    with open('/mnt/config/hostname') as handle:
        hostname = handle.read().strip()

    subprocess.call(['hostname', hostname])
    make_hosts_file(hostname)


def make_hosts_file(fqdn, extra_hosts=None):
    extra_hosts = [] if extra_hosts is None else extra_hosts

    hostname = fqdn.split('.')[0]
    suffix = None
    if hostname != fqdn:
        suffix = '.'.join(fqdn.split('.')[:1])

    contents = '127.0.0.1\tlocalhost\n'
    if suffix:
        contents += '127.0.1.0\t{}\t{}\n'.format(fqdn, hostname)
    else:
        contents += '127.0.1.0\t{}\n'.format(fqdn)
    contents += '\n'
    for host in extra_hosts:
        if suffix and '.' not in host[1]:
            contents += '{0}\t{1}{2}\t{1}\n'.format(host[0], host[1], suffix)
        else:
            contents += '{0}\t{1}\n'.format(host[0], host[1])

    with open('/mnt/config/hosts', 'w') as handle:
        handle.write(contents)


def _get_interface_names():
    result = []
    for interface in os.listdir('/sys/class/net/'):
        if interface.startswith('eth'):
            result.append(interface)
    return result


def _setup_static(device, name, ip, netmask, gateway=None):
    commands = [
        ['ip', 'link', 'set', 'dev', device, 'up'],
        ['brctl', 'addbr', name],
        ['brctl', 'addif', name, device],
        ['ip', 'address', 'add', '{}/{}'.format(ip, netmask), 'dev', device],
    ]
    if gateway:
        commands.append(['ip', 'route', 'add', 'default', 'via', gateway])

    for command in commands:
        subprocess.check_call(command)
