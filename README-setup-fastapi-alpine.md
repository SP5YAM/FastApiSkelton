# Generator pustej aplikacji FastAPI na Alpine Linux

Ten pakiet zawiera skrypt `setup-fastapi-alpine.sh`, który automatycznie przygotowuje kompletne środowisko pod prostą aplikację webową FastAPI na Alpine Linux.

Skrypt po uruchomieniu pyta o:

- nazwę systemu / aplikacji,
- port HTTP, na którym aplikacja ma działać.

Na tej podstawie tworzy katalog aplikacji w `/opt/<nazwa>`, instaluje środowisko Python `venv`, generuje pustą aplikację FastAPI, tworzy skrypty startowe, dodaje usługę OpenRC do autostartu i od razu uruchamia aplikację.

---

## 1. Wymagania

System:

```sh
Alpine Linux
```

Uprawnienia:

```sh
root
```

Skrypt musi być uruchomiony jako root, ponieważ:

- instaluje pakiety przez `apk`,
- tworzy katalog w `/opt`,
- tworzy usługę w `/etc/init.d`,
- dodaje usługę do autostartu OpenRC.

---

## 2. Plik instalatora

Plik:

```sh
setup-fastapi-alpine.sh
```

Nadaj uprawnienia wykonywania:

```sh
chmod +x setup-fastapi-alpine.sh
```

---

## 3. Uruchomienie

Jako root:

```sh
sh setup-fastapi-alpine.sh
```

albo:

```sh
./setup-fastapi-alpine.sh
```

Jeżeli używasz `doas`:

```sh
doas sh setup-fastapi-alpine.sh
```

Jeżeli używasz `sudo`:

```sh
sudo sh setup-fastapi-alpine.sh
```

---

## 4. Pytania instalatora

Po uruchomieniu skrypt zapyta o nazwę aplikacji:

```text
Podaj nazwę systemu/aplikacji:
```

Przykład:

```text
RFID Club
```

Z tej nazwy zostanie utworzona techniczna nazwa usługi i katalogu. Spacje oraz nietypowe znaki zostaną zamienione na myślniki i małe litery.

Przykład:

```text
RFID Club -> rfid-club
```

Katalog aplikacji będzie wtedy:

```text
/opt/rfid-club
```

Nazwa usługi OpenRC będzie:

```text
rfid-club
```

Następnie skrypt zapyta o port HTTP:

```text
Podaj port HTTP, np. 8000:
```

Przykład:

```text
8000
```

---

## 5. Co tworzy skrypt

Dla przykładowej nazwy `rfid-club` zostanie utworzona struktura:

```text
/opt/rfid-club
├── app
│   ├── __init__.py
│   ├── main.py
│   └── templates
│       └── index.html
├── static
├── requirements.txt
├── run.sh
├── start.sh
├── stop.sh
├── restart.sh
├── status.sh
└── venv
```

Dodatkowo zostanie utworzony plik usługi:

```text
/etc/init.d/rfid-club
```

Oraz katalog logów:

```text
/var/log/rfid-club
```

---

## 6. Co instaluje skrypt

Pakiety systemowe Alpine:

```sh
python3
py3-pip
py3-virtualenv
```

Pakiety Python w środowisku `venv`:

```text
fastapi
uvicorn[standard]
gunicorn
jinja2
python-multipart
```

---

## 7. Uruchomiona aplikacja testowa

Skrypt tworzy minimalną aplikację FastAPI.

Strona główna:

```text
http://127.0.0.1:<port>/
```

Healthcheck:

```text
http://127.0.0.1:<port>/health
```

Przykład dla portu `8000`:

```sh
curl http://127.0.0.1:8000/health
```

Oczekiwany wynik:

```json
{"status":"ok","app":"Nazwa aplikacji"}
```

Strona startowa jest w ciemnej tonacji i pokazuje nazwę aplikacji centralnie na środku strony.

---

## 8. Obsługa usługi OpenRC

Sprawdzenie statusu:

```sh
rc-service rfid-club status
```

Start:

```sh
rc-service rfid-club start
```

Stop:

```sh
rc-service rfid-club stop
```

Restart:

```sh
rc-service rfid-club restart
```

Dodanie do autostartu jest wykonywane automatycznie przez instalator:

```sh
rc-update add rfid-club default
```

Sprawdzenie, czy usługa jest w autostarcie:

```sh
rc-update show | grep rfid-club
```

---

## 9. Skrypty pomocnicze w katalogu aplikacji

W katalogu `/opt/<nazwa>` instalator tworzy proste skrypty:

```sh
./start.sh
./stop.sh
./restart.sh
./status.sh
```

Przykład:

```sh
cd /opt/rfid-club
./status.sh
```

Skrypt `status.sh` pokazuje status usługi i wykonuje test endpointu `/health`.

---

## 10. Logi

Dla przykładowej aplikacji `rfid-club` logi są w katalogu:

```text
/var/log/rfid-club
```

Podgląd logów:

```sh
tail -f /var/log/rfid-club/output.log /var/log/rfid-club/error.log
```

---

## 11. Ręczne uruchomienie aplikacji

Możesz zatrzymać usługę i uruchomić aplikację ręcznie, żeby zobaczyć błędy bezpośrednio w terminalu.

```sh
rc-service rfid-club stop
cd /opt/rfid-club
./run.sh
```

Domyślnie `run.sh` używa:

```text
HOST=0.0.0.0
PORT=8000
WORKERS=1
APP_MODULE=app.main:app
```

Można to nadpisać:

```sh
PORT=8080 ./run.sh
```

albo:

```sh
WORKERS=2 PORT=8000 ./run.sh
```

---

## 12. Gdzie edytować aplikację

Główny plik aplikacji:

```text
/opt/rfid-club/app/main.py
```

Szablon strony startowej:

```text
/opt/rfid-club/app/templates/index.html
```

Pliki statyczne:

```text
/opt/rfid-club/static
```

Po zmianach w kodzie wykonaj restart:

```sh
rc-service rfid-club restart
```

---

## 13. Aktualizacja zależności Python

Wejdź do katalogu aplikacji:

```sh
cd /opt/rfid-club
```

Aktywuj środowisko:

```sh
. venv/bin/activate
```

Zainstaluj zależności ponownie:

```sh
pip install -r requirements.txt
```

Restart usługi:

```sh
rc-service rfid-club restart
```

---

## 14. Usunięcie aplikacji

Zatrzymaj usługę:

```sh
rc-service rfid-club stop
```

Usuń z autostartu:

```sh
rc-update del rfid-club default
```

Usuń plik usługi:

```sh
rm /etc/init.d/rfid-club
```

Usuń katalog aplikacji:

```sh
rm -rf /opt/rfid-club
```

Opcjonalnie usuń logi:

```sh
rm -rf /var/log/rfid-club
```

---

## 15. Uwagi praktyczne

- Do małej aplikacji wewnętrznej wystarczy `WORKERS=1` i Uvicorn.
- Jeśli aplikacja ma być wystawiona na port 80, lepiej użyć reverse proxy, na przykład nginx albo Caddy.
- Każda aplikacja powinna mieć własny katalog w `/opt` i własne środowisko `venv`.
- Nie instaluj zależności `pip` globalnie w systemie.
- Jeżeli port jest już zajęty, usługa może nie wystartować. Sprawdź wtedy logi i aktywne porty.

Sprawdzenie portów:

```sh
ss -lntp
```

Test działania lokalnie:

```sh
curl http://127.0.0.1:8000/health
```
