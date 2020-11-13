import os
import argparse
import requests
import flask
from flask import render_template, redirect, url_for, send_from_directory

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


def download_deps():
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



def log(*args, **kwargs):
    print(*args, **kwargs, flush=True)


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


def is_static(path):
    if path in ("bm_xp.js", ):
        return False
    for static in (".js", ".css"):
        if path.endswith(static):
            return True
    return False


def serve(args):
    if args.debug:
        app.config["DEBUG"] = True
    app.run(host=args.host, port=args.port, debug=args.debug)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Browse benchmark results", prog="bm")
    subparsers = parser.add_subparsers()
    #
    sp = subparsers.add_parser("serve")
    sp.set_defaults(func=serve)
    sp.add_argument("-H", "--host", type=str, default="localhost", help="host. default=%(default)s")
    sp.add_argument("-p", "--port", type=int, default=8000, help="port. default=%(default)s")
    sp.add_argument("--debug", action="store_true", help="enable debug mode")
    #
    sp = subparsers.add_parser("deps")
    sp.set_defaults(func=lambda _: download_deps())
    #
    args = parser.parse_args()
    args.func(args)
