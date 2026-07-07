cat > /opt/dashboard/app/main.py <<'EOF'
from pathlib import Path
import logging

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

APP_TITLE = "dashboard"

BASE_DIR = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = BASE_DIR / "app" / "templates"
STATIC_DIR = BASE_DIR / "static"
LOG_DIR = BASE_DIR / "logs"

STATIC_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    filename=str(LOG_DIR / "app.log"),
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

app = FastAPI(title=APP_TITLE)

templates = Jinja2Templates(directory=str(TEMPLATE_DIR))

app.mount(
    "/static",
    StaticFiles(directory=str(STATIC_DIR)),
    name="static",
)


@app.get("/health")
def health():
    logging.info("Healthcheck requested")
    return {
        "status": "ok",
        "app": APP_TITLE,
    }


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    logging.info("Index page requested")
    return templates.TemplateResponse(
        name="index.html",
        request=request,
        context={
            "title": APP_TITLE,
        },
    )
EOF

rc-service dashboard restart
