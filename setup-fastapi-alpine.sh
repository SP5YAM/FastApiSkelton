#!/bin/sh
set -eu

# FastAPI skeleton installer for Alpine Linux / OpenRC
# Creates a complete empty FastAPI application in /opt/<app_name>
# with venv, run script, OpenRC service, logs, helper scripts and uninstall script.

echo "=============================================="
echo " FastAPI skeleton installer for Alpine Linux"
echo "=============================================="
echo

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

ask_value() {
    prompt="$1"
    default="$2"
    var=""
    printf "%s [%s]: " "$prompt" "$default"
    read var || true
    if [ -z "$var" ]; then
        var="$default"
    fi
    printf "%s" "$var"
}

APP_NAME="$(ask_value "Application/system name" "dashboard")"
APP_PORT="$(ask_value "HTTP port" "8000")"
APP_WORKERS="$(ask_value "Workers" "1")"

# Normalize app name for filesystem and OpenRC service
APP_NAME="$(printf "%s" "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-')"
APP_NAME="$(printf "%s" "$APP_NAME" | sed 's/^-*//; s/-*$//')"

if [ -z "$APP_NAME" ]; then
    echo "ERROR: Invalid application name."
    exit 1
fi

case "$APP_PORT" in
    ''|*[!0-9]*)
        echo "ERROR: Port must be a number."
        exit 1
        ;;
esac

case "$APP_WORKERS" in
    ''|*[!0-9]*)
        echo "ERROR: Workers must be a number."
        exit 1
        ;;
esac

APP_DIR="/opt/$APP_NAME"
SERVICE_FILE="/etc/init.d/$APP_NAME"

echo
echo "Application name : $APP_NAME"
echo "Application dir  : $APP_DIR"
echo "HTTP port        : $APP_PORT"
echo "Workers          : $APP_WORKERS"
echo

if [ -e "$APP_DIR" ]; then
    echo "ERROR: Directory already exists: $APP_DIR"
    echo "Choose another name or remove the existing directory first."
    exit 1
fi

if [ -e "$SERVICE_FILE" ]; then
    echo "ERROR: OpenRC service already exists: $SERVICE_FILE"
    exit 1
fi

echo "Installing system packages..."
apk update
apk add python3 py3-pip py3-virtualenv ca-certificates curl

update-ca-certificates || true

echo "Creating directory structure..."
mkdir -p "$APP_DIR/app/templates"
mkdir -p "$APP_DIR/static"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/data"

touch "$APP_DIR/app/__init__.py"

cat > "$APP_DIR/requirements.txt" <<'EOF'
fastapi
uvicorn[standard]
gunicorn
jinja2
python-multipart
EOF

echo "Creating Python venv..."
python3 -m venv "$APP_DIR/venv"

echo "Installing Python dependencies..."
"$APP_DIR/venv/bin/python" -m pip install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo "Creating FastAPI app..."
cat > "$APP_DIR/app/main.py" <<EOF
from pathlib import Path
import logging

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

APP_NAME = "$APP_NAME"

BASE_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = BASE_DIR / "logs"
STATIC_DIR = BASE_DIR / "static"
TEMPLATE_DIR = BASE_DIR / "app" / "templates"

LOG_DIR.mkdir(exist_ok=True)
STATIC_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    filename=str(LOG_DIR / "app.log"),
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

app = FastAPI(title=APP_NAME)

templates = Jinja2Templates(directory=str(TEMPLATE_DIR))
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/health")
def health():
    logging.info("Healthcheck requested")
    return {
        "status": "ok",
        "app": APP_NAME,
    }


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    logging.info("Index page requested")
    return templates.TemplateResponse(
        name="index.html",
        request=request,
        context={
            "title": APP_NAME,
        },
    )
EOF

echo "Creating HTML template..."
cat > "$APP_DIR/app/templates/index.html" <<'EOF'
<!doctype html>
<html lang="pl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ title }}</title>
    <style>
        :root {
            color-scheme: dark;
        }

        * {
            box-sizing: border-box;
        }

        html,
        body {
            margin: 0;
            min-height: 100%;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background:
                radial-gradient(circle at top left, rgba(0, 170, 255, 0.22), transparent 34rem),
                radial-gradient(circle at bottom right, rgba(0, 255, 170, 0.14), transparent 32rem),
                #080b12;
            color: #f5f7fb;
        }

        body {
            min-height: 100vh;
            display: grid;
            place-items: center;
            padding: 2rem;
        }

        main {
            text-align: center;
            padding: 3rem 4rem;
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 28px;
            background: rgba(10, 16, 28, 0.72);
            box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45);
            backdrop-filter: blur(16px);
        }

        h1 {
            margin: 0;
            font-size: clamp(2.4rem, 8vw, 6rem);
            line-height: 1;
            letter-spacing: -0.06em;
            text-transform: uppercase;
        }

        p {
            margin: 1.2rem 0 0;
            color: rgba(245, 247, 251, 0.68);
            font-size: 1rem;
        }

        .dot {
            width: 0.7rem;
            height: 0.7rem;
            display: inline-block;
            border-radius: 50%;
            background: #23d18b;
            box-shadow: 0 0 24px rgba(35, 209, 139, 0.8);
            margin-right: 0.45rem;
            vertical-align: middle;
        }
    </style>
</head>
<body>
    <main>
        <h1>{{ title }}</h1>
        <p><span class="dot"></span>FastAPI application is running</p>
    </main>
</body>
</html>
EOF

echo "Creating run.sh..."
cat > "$APP_DIR/run.sh" <<EOF
#!/bin/sh
set -eu

APP_MODULE="\${APP_MODULE:-app.main:app}"
HOST="\${HOST:-0.0.0.0}"
PORT="\${PORT:-$APP_PORT}"
WORKERS="\${WORKERS:-$APP_WORKERS}"

APP_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
cd "\$APP_DIR"

mkdir -p logs

echo "\$(date '+%Y-%m-%d %H:%M:%S') Starting $APP_NAME on \$HOST:\$PORT with \$WORKERS worker(s)" >> logs/output.log

if [ ! -x "venv/bin/python" ]; then
    echo "ERROR: venv not found in \$APP_DIR/venv" >&2
    exit 1
fi

if [ "\$WORKERS" = "1" ]; then
    exec venv/bin/uvicorn "\$APP_MODULE" --host "\$HOST" --port "\$PORT" --proxy-headers
else
    exec venv/bin/gunicorn "\$APP_MODULE" \\
        -k uvicorn.workers.UvicornWorker \\
        --bind "\$HOST:\$PORT" \\
        --workers "\$WORKERS" \\
        --access-logfile "-" \\
        --error-logfile "-"
fi
EOF
chmod +x "$APP_DIR/run.sh"

echo "Creating helper scripts..."
cat > "$APP_DIR/start.sh" <<EOF
#!/bin/sh
exec rc-service "$APP_NAME" start
EOF

cat > "$APP_DIR/stop.sh" <<EOF
#!/bin/sh
exec rc-service "$APP_NAME" stop
EOF

cat > "$APP_DIR/restart.sh" <<EOF
#!/bin/sh
exec rc-service "$APP_NAME" restart
EOF

cat > "$APP_DIR/status.sh" <<EOF
#!/bin/sh
exec rc-service "$APP_NAME" status
EOF

cat > "$APP_DIR/logs.sh" <<EOF
#!/bin/sh
mkdir -p "$APP_DIR/logs"
touch "$APP_DIR/logs/output.log" "$APP_DIR/logs/error.log" "$APP_DIR/logs/app.log"
exec tail -f "$APP_DIR/logs/output.log" "$APP_DIR/logs/error.log" "$APP_DIR/logs/app.log"
EOF

chmod +x "$APP_DIR/start.sh" "$APP_DIR/stop.sh" "$APP_DIR/restart.sh" "$APP_DIR/status.sh" "$APP_DIR/logs.sh"

echo "Creating uninstall.sh..."
cat > "$APP_DIR/uninstall.sh" <<EOF
#!/bin/sh
set -eu

APP_NAME="$APP_NAME"
APP_DIR="$APP_DIR"
SERVICE_FILE="/etc/init.d/$APP_NAME"

if [ "\$(id -u)" -ne 0 ]; then
    echo "ERROR: Run uninstall as root."
    exit 1
fi

echo "Uninstalling \$APP_NAME..."

if rc-service "\$APP_NAME" status >/dev/null 2>&1; then
    rc-service "\$APP_NAME" stop || true
fi

if rc-update show default | grep -q "^ *\$APP_NAME"; then
    rc-update del "\$APP_NAME" default || true
fi

if [ -f "\$SERVICE_FILE" ]; then
    rm -f "\$SERVICE_FILE"
fi

if [ "\${1:-}" = "--purge" ]; then
    rm -rf "\$APP_DIR"
    echo "Removed \$APP_DIR"
    exit 0
fi

printf "Remove application directory %s ? [y/N]: " "\$APP_DIR"
read answer || true
case "\$answer" in
    y|Y|yes|YES)
        rm -rf "\$APP_DIR"
        echo "Removed \$APP_DIR"
        ;;
    *)
        echo "Application directory kept: \$APP_DIR"
        ;;
esac

echo "Done."
EOF
chmod +x "$APP_DIR/uninstall.sh"

echo "Creating OpenRC service..."
cat > "$SERVICE_FILE" <<EOF
#!/sbin/openrc-run

name="$APP_NAME"
description="FastAPI web application: $APP_NAME"

directory="$APP_DIR"
command="$APP_DIR/run.sh"
command_args=""
command_background="yes"

pidfile="/run/\${RC_SVCNAME}.pid"

output_log="$APP_DIR/logs/output.log"
error_log="$APP_DIR/logs/error.log"

export HOST="0.0.0.0"
export PORT="$APP_PORT"
export WORKERS="$APP_WORKERS"
export APP_MODULE="app.main:app"

depend() {
    need net
}
EOF

chmod +x "$SERVICE_FILE"

echo "Adding service to autostart..."
rc-update add "$APP_NAME" default

echo "Starting service..."
rc-service "$APP_NAME" start

echo
echo "=============================================="
echo " Installation complete"
echo "=============================================="
echo "Application directory: $APP_DIR"
echo "Service name         : $APP_NAME"
echo "URL                  : http://127.0.0.1:$APP_PORT/"
echo "Healthcheck          : http://127.0.0.1:$APP_PORT/health"
echo
echo "Useful commands:"
echo "  rc-service $APP_NAME status"
echo "  rc-service $APP_NAME restart"
echo "  $APP_DIR/logs.sh"
echo "  $APP_DIR/uninstall.sh"
echo "  $APP_DIR/uninstall.sh --purge"
echo
