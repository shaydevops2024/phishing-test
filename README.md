# Phishing-awareness test

An **internal, authorized** phishing-awareness simulation for IConduct employees.

- Bait page (`/`): a fake payroll "verify your info" form asking for **full name** + **work email**.
- On submit, the data is stored and the user is redirected to `/gotcha`.
- Reveal page (`/gotcha`): shows the "you've been phished" message + a 5-minute
  countdown, then after **2 seconds** pops up a "just kidding, this was a test" modal
  pointing people to report at `shay.gu@iconductcloud.com`.

It collects only: **full name, work email, public IP, timestamp** — no passwords.

## Layout

```
app/                 Flask web app + Dockerfile + templates
docker-compose.yml   web (port 80) + postgres (volume, not exposed)
.env                 secrets / config (copy from .env.example)
deploy.sh            one-shot deploy script for a fresh Ubuntu server
```

## Run locally / on the server

```bash
cp .env.example .env          # then edit the password
docker compose up -d --build
# open http://localhost/  (or http://<server-ip>/)
```

## Read captured data

```bash
docker compose exec db psql -U phishing -d phishing \
  -c "SELECT full_name, work_email, public_ip, captured_at FROM captures ORDER BY captured_at DESC;"
```

## Deploy on your Ubuntu server

Create the EC2 (or any Ubuntu) instance yourself, then copy this project up and
run the deploy script. It installs Docker + Compose if missing, builds, and starts
everything.

```bash
scp -r ./phishing-test ubuntu@<server-ip>:~/
ssh ubuntu@<server-ip>
cd phishing-test
./deploy.sh
```

> The first run creates `.env` from the example and stops so you can set a strong
> `POSTGRES_PASSWORD`. Edit it, then run `./deploy.sh` again.
>
> Make sure the server's security group / firewall allows inbound **80** (web) and
> **22** (SSH). Postgres (5432) stays internal to the Docker network and is never
> exposed publicly.

## Sample bait email

> **Subject:** Action required: verify your details before this month's salary
>
> Hi,
>
> Before payroll is processed this month, all employees must confirm their
> identity to avoid a delay in payment. Please verify your information within
> 24 hours using the secure link below:
>
> 👉 http://<server-ip>/
>
> Thank you,
> IConduct Payroll Team

## ⚠️ Use responsibly

Run this only against your own organization's employees, with management/HR
awareness, and debrief participants afterward. The reveal popup and reporting
address are built in for exactly that purpose.
