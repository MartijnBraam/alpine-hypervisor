from flask import Flask, url_for, redirect, render_template

import webui.storage as storage
import webui.networking as networking

app = Flask(__name__)
installed = False


@app.route('/')
def home():
    if not installed:
        return redirect(url_for('setup_storage'))
    return 'Hello World!'


@app.route('/setup/storage')
def setup_storage():
    return render_template('oobe/oobe1.html.j2')


if __name__ == '__main__':
    installed = storage.mount_config_partition()
    if installed:
        networking.setup_from_config()
    else:
        networking.setup_all_dhcp()
    app.run(host='0.0.0.0')
