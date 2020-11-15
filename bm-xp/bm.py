import os
import sys
import argparse
import requests
import flask
import json
import re
from flask import render_template, redirect, url_for, send_from_directory


def log(*args, **kwargs):
    print(*args, **kwargs, flush=True)


def get_manifest(args):
    if len(args.bmdir) > 1:
        raise Exception("not implemented")
    d = args.bmdir[0]
    title = 'foo'  # FIXME
    prefix = 'c4core-bm-'
    bms = {}
    log("entering", d)
    for filename in os.listdir(d):
        if not filename.endswith('.json'):
            log("ignoring", filename)
            continue
        log("adding", filename)
        name = filename.replace('.json', '')
        name = name.replace(prefix, '')
        log(f"name={name}")
        bm_prefix = re.sub(r"(.*?)-.*", r"\1", name)
        bm_subprefix = re.sub(r"(.*?)-(.*?).*", r"\2", name)
        bms[name] = {
            'desc': name,
            'prefix': bm_prefix,
            'subprefix': bm_subprefix,
            'src': '',
            'results': filename
        }
        log(bms[name])
    manifest = {
        'name': 'foo',
        'benchmarks': bms
    }
    manifest_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'manifest.json')
    log("writing manifest", manifest_file)
    with open(manifest_file, "w") as f:
        f.write(json.dumps(manifest, indent=2, sort_keys=True))
    return manifest


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

app = flask.Flask(__name__, static_url_path='',
                  static_folder='static',
                  template_folder='template')


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/<path>")
def other(path):
    log("requested path:", path)
    if is_static(path):
        log("aqui 2")
        return send_from_directory('static', path)
    else:
        log("aqui 3")
        return send_from_directory('', path)


@app.route("/bm/<path>")
def result(path):
    if len(args.bmdir) > 1:
        raise Exception("not implemented")
    d = args.bmdir[0]
    log("requested result:", path, "---", os.path.join(d, path))
    return send_from_directory(d, path)


@app.context_processor
def override_url_for():
    """
    Generate a new token on every request to prevent the browser from
    caching static files.
    """
    return dict(url_for=dated_url_for)


def dated_url_for(endpoint, **values):
    log("endpoint:", endpoint)
    if endpoint == 'static':
        filename = values.get('filename', None)
        if filename:
            file_path = os.path.join(app.root_path,
                                     endpoint, filename)
            values['q'] = int(os.stat(file_path).st_mtime)
    return url_for(endpoint, **values)


def is_static(path):
    if path in ("bm.js", ):
        return False
    for static in (".js", ".css"):
        if path.endswith(static):
            return True
    return False


def serve(args):
    def _s(prop, val):
        assert not hasattr(app, prop), prop
        setattr(app, prop, val)
    _s('args', args)
    _s('manifest', get_manifest(args))
    if args.debug:
        app.config["DEBUG"] = True
    app.run(host=args.host, port=args.port, debug=args.debug)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

def download_deps():
    deps = [
        "https://code.jquery.com/jquery-3.3.1.js",
        "https://code.jquery.com/jquery-3.3.1.js",
        "https://code.jquery.com/ui/1.12.1/jquery-ui.js",
        "https://cdn.datatables.net/1.10.20/js/jquery.dataTables.js",
        "https://cdn.datatables.net/1.10.20/js/jquery.dataTables.min.js",
        "https://cdn.datatables.net/1.10.20/css/jquery.dataTables.css",
        "https://cdn.datatables.net/1.10.20/css/jquery.dataTables.min.css",
        "https://www.chartjs.org/dist/2.9.1/Chart.min.js",
        #("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.3.2/styles/github.css", "highlight.github.css"),
        ("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.3.2/styles/github.min.css", "highlight.github.min.css"),
        #"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.3.2/highlight.js",
        "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/10.3.2/highlight.min.js",
    ]
    for src in deps:
        if type(src) == str:
            base = os.path.basename(src)
        else:
            src, base = src
        dst = f"{os.getcwd()}/static/{base}"
        download_url(src, dst)


def download_url(url, dst):
    log("download url:", url, "--->", dst)
    req = requests.get(url, stream=True)
    if req.status_code == 200:
        sz = 0
        with open(dst, 'wb') as f:
            for chunk in req:
                f.write(chunk)
                sz += len(chunk)
        log(f"........ finished: {sz}B")
    else:
        log(f"         error:", req.status_code, url)


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

if __name__ == '__main__':
    #
    parser = argparse.ArgumentParser(description="Browse benchmark results", prog="bm")
    subparsers = parser.add_subparsers()
    #
    sp = subparsers.add_parser("serve")
    sp.set_defaults(func=serve)
    sp.add_argument("bmdir", type=str, nargs="*", default=[os.getcwd()], help="the directory with the results. default=.")
    sp.add_argument("-H", "--host", type=str, default="localhost", help="host. default=%(default)s")
    sp.add_argument("-p", "--port", type=int, default=8000, help="port. default=%(default)s")
    sp.add_argument("--debug", action="store_true", help="enable debug mode")
    #
    sp = subparsers.add_parser("deps")
    sp.set_defaults(func=lambda _: download_deps())
    #
    args = parser.parse_args(sys.argv[1:] if len(sys.argv) > 1 else ["serve"])
    if args.debug:
        log(args)
    args.func(args)
