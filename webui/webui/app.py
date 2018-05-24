from flask import Flask, url_for, redirect, render_template, request

import webui.storage as storage
import webui.networking as networking

app = Flask(__name__)
installed = False


@app.route('/')
def home():
    if not installed:
        return redirect(url_for('setup_storage'))
    return 'Hello World!'


@app.route('/setup/storage', methods=['GET', 'POST'])
def setup_storage():
    disks = storage.get_disks()
    if request.method == "POST":
        group_bulk = []
        group_cache = []
        for key in request.form:
            if key.startswith('disk_'):
                disk = '/dev/' + key.replace('disk_', '')
                if request.form[key] == 'bulk':
                    group_bulk.append(disk)
                elif request.form[key] == 'cache':
                    group_cache.append(disk)
        storage.format_bcachefs(bulk=group_bulk, cache=group_cache)
    return render_template('oobe/oobe1.html.j2', disks=disks)


if __name__ == '__main__':
    test = True
    installed = False
    if not test:
        installed = storage.mount_config_partition()
    if installed:
        networking.setup_from_config()
    else:
        if not test:
            networking.setup_all_dhcp()
    app.run(host='0.0.0.0')
