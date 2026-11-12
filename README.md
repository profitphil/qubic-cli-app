# Qubic iOS App (personal build)

A SwiftUI iOS app that drives the full [qubic-cli](https://github.com/qubic/qubic-cli) command surface remotely via a tiny Go API running on your VPS.

**Not for the App Store.** This exposes every CLI command — wallet, node admin, smart contracts, debug — which Apple would reject. Sideload only, free Apple ID, re-sign every 7 days.

```
  iPhone  ───HTTPS+bearer──▶  VPS:Caddy:443  ─▶  qubic-api  ─▶  qubic-cli
                                                      │
                                                      └─ subprocess exec
```

## 1. VPS setup (Ubuntu 24.04)

```bash
# on your Mac
scp -r deploy backend root@YOUR_VPS_IP:/root/qubic-api-src
ssh root@YOUR_VPS_IP

# on the VPS
cd /root/qubic-api-src
# with a domain (recommended: point DNS A-record at the VPS first)
DOMAIN=api.yourdomain.com bash deploy/install.sh

# or without a domain (localhost:8787, use SSH tunnel or Tailscale)
bash deploy/install.sh
```

The installer:
- builds `qubic-cli` from source → `/usr/local/bin/qubic-cli`
- builds the Go API → `/usr/local/bin/qubic-api`
- creates `qubic` system user + `/var/lib/qubic-api`
- generates a random bearer token → **printed once, also in `/etc/qubic-api.env`**
- installs + starts `qubic-api.service` (systemd, hardened sandbox)
- if `DOMAIN` set: installs Caddy with Let's Encrypt auto-TLS

**Save the printed `API_TOKEN`** — you'll paste it into the iOS app.

### No domain? Use Tailscale (recommended)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
tailscale ip -4     # note the 100.x.x.x address
```

Install Tailscale on your iPhone, sign in to the same account. In the app's Settings, use `http://100.x.x.x:8787` as the base URL. No domain, no TLS certs, private.

### Verify
```bash
curl -s http://127.0.0.1:8787/healthz
# {"status":"ok"}

curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"args":["-help"]}' \
     http://127.0.0.1:8787/exec | jq .
```

## 2. iOS app (Xcode)

The Swift files live in `ios/QubicApp/`. The repo doesn't ship an `.xcodeproj` — create one yourself:

1. Open Xcode → **File → New → Project → iOS → App**
2. Settings:
   - Product name: `QubicApp`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Bundle identifier: `com.yourname.qubicapp` (any unique string)
3. Close the template files Xcode generated (`ContentView.swift`, etc.). Delete them.
4. In Finder, drag **all contents of `ios/QubicApp/`** into the Xcode project navigator. Check **"Copy items if needed"** and **"Create groups"**.
5. Make sure `Resources/commands.json` and `Resources/categories.json` are in the **Copy Bundle Resources** build phase. (Xcode usually does this automatically for JSON dragged into the project.)
6. Targets → QubicApp → Signing & Capabilities → **Team**: pick your free Apple ID. Xcode will auto-generate a provisioning profile.
7. Plug in your iPhone, select it as the run destination, press **⌘R**.

First launch the app will look empty-ish — go to **Settings** tab:
- **Base URL**: `https://api.yourdomain.com` or `http://100.x.x.x:8787` (Tailscale)
- **API token**: paste the one from the installer
- **Node IP / port**: your preferred Qubic node (optional; auto-injected into every command)
- **Seed**: 55-char seed, stored in iOS Keychain. Only used for commands marked 🔑.
- Tap **Test connection** — should say ✓ Reachable.

Now Browse → pick a category → pick a command → fill args → Run.

### Free Apple ID caveats

- App expires every **7 days**; re-plug and re-run from Xcode to extend.
- Max 3 sideloaded apps at once.
- No push notifications, no background modes (we don't need them).

If that gets old, $99/yr Apple Developer gets you 1-year signing.

## 3. Security notes

- **Token** is random 48-char base64, stored in `/etc/qubic-api.env` (root:qubic 0640) and in iOS Keychain on the phone.
- **Seed** never leaves the phone except inside the `-seed` arg of each request over HTTPS to your own backend. The backend does not persist args; it shells out and returns.
- **Backend** runs as a non-root `qubic` user, systemd sandbox (no new privs, read-only root fs, private tmp, etc.).
- **Concurrency**: a mutex serializes `/exec` calls so two tx signings don't clash.
- **No shell**: args are passed directly to `execve`, no shell expansion. Null bytes and over-long args are rejected.

## 4. Project layout

```
backend/           Go API (single file, stdlib only)
  main.go
  go.mod
deploy/
  install.sh       one-shot VPS installer
  qubic-api.service
  Caddyfile
schema/
  commands.json    199 commands, parsed from argparser.h
  categories.json  16 categories w/ SF Symbol icons
ios/QubicApp/
  QubicApp.swift   @main
  Models.swift
  Catalog.swift    loads bundled JSON
  Settings.swift   UserDefaults + Keychain
  API.swift        URLSession client
  History.swift    recent + favorites
  Info.plist
  Views/
    RootView.swift
    CategoriesView.swift
    CommandListView.swift
    CommandDetailView.swift
    ResultView.swift
    HistoryView.swift
    SettingsView.swift
  Resources/
    commands.json      ← bundled copy of schema/
    categories.json
upstream/          qubic-cli source (reference only)
```

## 5. Updating the command catalog

When qubic-cli adds new flags upstream:

```bash
cd upstream && git pull
# re-run the schema extractor (see schema/ — or just hand-edit commands.json)
cp schema/commands.json ios/QubicApp/Resources/commands.json
cp schema/categories.json ios/QubicApp/Resources/categories.json
# rebuild iOS app
```

On the VPS, rebuild qubic-cli:
```bash
cd /root/qubic-api-src && DOMAIN=api.yourdomain.com bash deploy/install.sh
```
(The installer is idempotent and will rebuild qubic-cli + restart the service.)

## 6. Known limitations of v1

- The schema-driven form can't know every flag's nuance — some commands may need tweaks to their arg definitions in `commands.json`. The form is generic; fix the JSON and rebuild.
- Boolean flags are modeled as key-only (present/absent). Double-check a few tx commands before trusting them with real qubic.
- No biometric auth on the app yet (Face ID gate before running signing commands is an easy add — ask if you want it).
- No streaming output — long-running commands block the API until done (60s default, configurable per request).
