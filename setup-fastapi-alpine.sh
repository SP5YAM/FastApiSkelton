#!/bin/sh
# setup-fastapi-alpine.sh
# Generator pustej aplikacji FastAPI na Alpine Linux z usługą OpenRC.
# Tworzy /opt/<nazwa>, venv, aplikację startową, skrypty obsługi i autostart.

set -eu

need_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Ten skrypt uruchom jako root, np.:"
        echo "  doas sh $0"
        echo "albo:"
        echo "  sudo sh $0"
        exit 1
    fi
}

slugify() {
    # Alpine busybox-friendly sanitizacja nazwy usługi/katalogu.
    # Zamienia spacje i nietypowe znaki na '-'.
    echo "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | tr ' _' '--' \
        | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

valid_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *)
            [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
            ;;
    esac
}

ask() {
    printf "%s" "$1"
    read -r REPLY
}

need_root

echo "Generator środowiska FastAPI dla Alpine Linux"
echo

ask "Podaj nazwę systemu/aplikacji: "
APP_TITLE="$REPLY"

if [ -z "$APP_TITLE" ]; then
    echo "Nazwa nie może być pusta."
    exit 1
fi

APP_NAME="$(slugify "$APP_TITLE")"

if [ -z "$APP_NAME" ]; then
    echo "Nie udało się utworzyć poprawnej nazwy katalogu/usługi."
    echo "Użyj liter, cyfr albo myślnika."
    exit 1
fi

if [ "$APP_NAME" != "$APP_TITLE" ]; then
    echo "Nazwa techniczna została uproszczona do: $APP_NAME"
fi

ask "Podaj port HTTP, np. 8000: "
APP_PORT="$REPLY"

if ! valid_port "$APP_PORT"; then
    echo "Niepoprawny port: $APP_PORT"
    exit 1
fi

APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME"
INIT_FILE="/etc/init.d/$SERVICE_NAME"
LOG_DIR="/var/log/$APP_NAME"

echo
echo "Zostanie utworzone środowisko:"
echo "  nazwa:     $APP_TITLE"
echo "  katalog:   $APP_DIR"
echo "  usługa:    $SERVICE_NAME"
echo "  port:      $APP_PORT"
echo

if [ -e "$APP_DIR" ]; then
    ask "Katalog $APP_DIR już istnieje. Nadpisać pliki aplikacji? [tak/N]: "
    case "$REPLY" in
        tak|TAK|t|T|yes|YES|y|Y) ;;
        *)
            echo "Przerwano."
            exit 1
            ;;
    esac
fi

echo "Instaluję pakiety systemowe..."
apk update
apk add python3 py3-pip py3-virtualenv

mkdir -p "$APP_DIR/app/templates" "$APP_DIR/static" "$LOG_DIR"

cat > "$APP_DIR/requirements.txt" <<'EOF'
fastapi
uvicorn[standard]
gunicorn
jinja2
python-multipart
EOF

touch "$APP_DIR/app/__init__.py"

cat > "$APP_DIR/app/main.py" <<EOF
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

APP_TITLE = $(APP_TITLE_VALUE="$APP_TITLE" python3 -c 'import os, json; print(json.dumps(os.environ["APP_TITLE_VALUE"]))')

app = FastAPI(title=APP_TITLE)

templates = Jinja2Templates(directory="app/templates")
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "app": APP_TITLE,
    }


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "title": APP_TITLE,
        },
    )
EOF

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
            --bg1: #050711;
            --bg2: #111827;
            --text: #f8fafc;
            --muted: #94a3b8;
            --accent: #38bdf8;
            --accent2: #22c55e;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background:
                radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.18), transparent 32rem),
                radial-gradient(circle at 80% 80%, rgba(34, 197, 94, 0.14), transparent 30rem),
                linear-gradient(135deg, var(--bg1), var(--bg2));
            color: var(--text);
            display: grid;
            place-items: center;
            overflow: hidden;
        }

        .card {
            width: min(90vw, 760px);
            padding: 4rem 2rem;
            border: 1px solid rgba(148, 163, 184, 0.22);
            border-radius: 28px;
            background: rgba(15, 23, 42, 0.72);
            box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45);
            backdrop-filter: blur(16px);
            text-align: center;
        }

        .label {
            color: var(--accent);
            letter-spacing: 0.18em;
            text-transform: uppercase;
            font-size: 0.82rem;
            font-weight: 700;
            margin-bottom: 1.25rem;
        }

        h1 {
            margin: 0;
            font-size: clamp(2.2rem, 7vw, 5.5rem);
            line-height: 1.05;
            font-weight: 850;
        }

        .status {
            margin-top: 1.6rem;
            color: var(--muted);
            font-size: 1.05rem;
        }

        .dot {
            display: inline-block;
            width: 0.65rem;
            height: 0.65rem;
            margin-right: 0.5rem;
            border-radius: 50%;
            background: var(--accent2);
            box-shadow: 0 0 20px var(--accent2);
            vertical-align: middle;
        }
    </style>
</head>
<body>
    <main class="card">
        <div class="label">FastAPI / Alpine Linux</div>
        <h1>{{ title }}</h1>
        <div class="status"><span class="dot"></span>Aplikacja działa</div>
    </main>
</body>
</html>
EOF

cat > "$APP_DIR/run.sh" <<'EOF'
#!/bin/sh
set -eu

APP_MODULE="${APP_MODULE:-app.main:app}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
WORKERS="${WORKERS:-1}"

cd "$(dirname "$0")"

if [ ! -x "venv/bin/python" ]; then
    echo "Brak venv w katalogu: $(pwd)/venv"
    echo "Uruchom ponownie instalator albo wykonaj:"
    echo "  python3 -m venv venv"
    echo "  . venv/bin/activate"
    echo "  pip install -r requirements.txt"
    exit 1
fi

if [ "$WORKERS" = "1" ]; then
    exec venv/bin/uvicorn "$APP_MODULE" --host "$HOST" --port "$PORT"
else
    exec venv/bin/gunicorn "$APP_MODULE" \
        -k uvicorn.workers.UvicornWorker \
        --bind "$HOST:$PORT" \
        --workers "$WORKERS"
fi
EOF

cat > "$APP_DIR/start.sh" <<EOF
#!/bin/sh
rc-service "$SERVICE_NAME" start
EOF

cat > "$APP_DIR/stop.sh" <<EOF
#!/bin/sh
rc-service "$SERVICE_NAME" stop
EOF

cat > "$APP_DIR/restart.sh" <<EOF
#!/bin/sh
rc-service "$SERVICE_NAME" restart
EOF

cat > "$APP_DIR/status.sh" <<EOF
#!/bin/sh
rc-service "$SERVICE_NAME" status
echo
echo "Test health:"
curl -fsS "http://127.0.0.1:$APP_PORT/health" || true
echo
EOF

chmod +x "$APP_DIR/run.sh" "$APP_DIR/start.sh" "$APP_DIR/stop.sh" "$APP_DIR/restart.sh" "$APP_DIR/status.sh"

echo "Tworzę środowisko venv..."
cd "$APP_DIR"
python3 -m venv venv

echo "Instaluję zależności Python..."
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

cat > "$INIT_FILE" <<EOF
#!/sbin/openrc-run

name="$SERVICE_NAME"
description="FastAPI web application: $APP_TITLE"

directory="$APP_DIR"
command="$APP_DIR/run.sh"
command_args=""
command_background="yes"

pidfile="/run/\${RC_SVCNAME}.pid"
output_log="$LOG_DIR/output.log"
error_log="$LOG_DIR/error.log"

export HOST="0.0.0.0"
export PORT="$APP_PORT"
export WORKERS="1"
export APP_MODULE="app.main:app"

depend() {
    need net
}
EOF

chmod +x "$INIT_FILE"

echo "Dodaję usługę do autostartu..."
rc-update add "$SERVICE_NAME" default

if rc-service "$SERVICE_NAME" status >/dev/null 2>&1; then
    echo "Usługa już działa, restartuję..."
    rc-service "$SERVICE_NAME" restart
else
    echo "Startuję usługę..."
    rc-service "$SERVICE_NAME" start
fi

echo
echo "Gotowe."
echo "Aplikacja:  $APP_TITLE"
echo "Katalog:    $APP_DIR"
echo "Usługa:     $SERVICE_NAME"
echo "Adres:      http://127.0.0.1:$APP_PORT/"
echo "Health:     http://127.0.0.1:$APP_PORT/health"
echo
echo "Przydatne komendy:"
echo "  rc-service $SERVICE_NAME status"
echo "  rc-service $SERVICE_NAME restart"
echo "  rc-service $SERVICE_NAME stop"
echo "  tail -f $LOG_DIR/output.log $LOG_DIR/error.log"
