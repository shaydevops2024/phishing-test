import os
import time

import psycopg2
from flask import Flask, redirect, render_template, request, url_for

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "db"),
    "port": os.environ.get("DB_PORT", "5432"),
    "dbname": os.environ.get("DB_NAME", "phishing"),
    "user": os.environ.get("DB_USER", "phishing"),
    "password": os.environ.get("DB_PASSWORD", "changeme"),
}

# Reporting address shown on the reveal popup.
REPORT_EMAIL = os.environ.get("REPORT_EMAIL", "shay.gu@iconductcloud.com")


def get_conn():
    return psycopg2.connect(**DB_CONFIG)


def init_db():
    """Create the captures table, retrying until the DB is reachable."""
    last_err = None
    for _ in range(30):
        try:
            conn = get_conn()
            cur = conn.cursor()
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS captures (
                    id          SERIAL PRIMARY KEY,
                    full_name   TEXT NOT NULL,
                    work_email  TEXT NOT NULL,
                    public_ip   TEXT,
                    captured_at TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                """
            )
            conn.commit()
            cur.close()
            conn.close()
            print("DB initialized", flush=True)
            return
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"DB not ready ({e}); retrying in 2s...", flush=True)
            time.sleep(2)
    raise RuntimeError(f"Could not connect to DB: {last_err}")


def client_ip():
    """Best-effort public IP of the requester (honours X-Forwarded-For)."""
    xff = request.headers.get("X-Forwarded-For", "")
    if xff:
        return xff.split(",")[0].strip()
    return request.remote_addr


def save_capture(full_name, email, ip):
    """Insert one captured record; never raises (errors are logged)."""
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO captures (full_name, work_email, public_ip) "
            "VALUES (%s, %s, %s)",
            (full_name, email, ip),
        )
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:  # noqa: BLE001
        print(f"Error saving capture: {e}", flush=True)


@app.route("/")
def index():
    return render_template("verify.html")


@app.route("/submit", methods=["POST"])
def submit():
    work_email = request.form.get("work_email", "").strip()
    ip = client_ip()
    email_lower = work_email.lower()

    # Addresses that are never accepted (e.g. shared mailboxes). Loop the user
    # back to the form, same as a non-company address — no message shown.
    BLOCKED_EMAILS = {"supportuser@iconductcloud.com"}
    if not email_lower.endswith("@iconductcloud.com") or email_lower in BLOCKED_EMAILS:
        return redirect(url_for("index"))

    # Store the local part (everything before "@iconductcloud.com") as the name.
    full_name = work_email.split("@", 1)[0]
    save_capture(full_name, work_email, ip)
    return redirect(url_for("gotcha"))


@app.route("/gotcha")
def gotcha():
    return render_template("gotcha.html", report_email=REPORT_EMAIL)


@app.route("/tips")
def tips():
    return render_template("tips.html", report_email=REPORT_EMAIL)


@app.route("/finish")
def finish():
    return render_template("finish.html", report_email=REPORT_EMAIL)


@app.route("/health")
def health():
    return "ok", 200


# Initialise the schema on import so it runs under gunicorn too.
init_db()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
