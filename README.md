# Rift Connection Check

A single static page (`index.html`) that a user opens on their phone to check whether their device and
network can reach every service the Rift / Rift Academy app depends on at startup. The user only sees a
progress bar; at the end they copy or share a base64-encoded JSON report back to support.

## What it checks

Each host is probed 3 times, sequentially, with a 10 s timeout: the API gateway `/ping` and GraphQL
endpoint, both CDNs, notifications, Privy, RevenueCat, Amplitude, AppsFlyer, Expo Updates and Sentry.
Hosts flagged `critical` are the ones the app waits on before it leaves the splash screen.

The gateway WebSocket (`/ws/orders`) is deliberately not probed: it needs an auth header a browser can't
send, and a browser reports the server's 401 as the same opaque error as a blocked connection.

## Reading a report

```sh
pbpaste | base64 -d | jq
```

```jsonc
{
  "v": 1,
  "startedAt": "…", "finishedAt": "…", "durationMs": 31000,
  "summary": {
    "failedCritical": ["amplitude"],   // critical hosts with 0/3 successful attempts
    "failed": ["amplitude"],           // any host with 0/3
    "unstable": []                     // some attempts failed, or median > 3 s
  },
  "device": { "userAgent": "…", "language": "en-US", "timeZone": "…", "online": true, "connection": null },
  "network": { "country": "DE", "edge": "FRA", "warp": "off", "http": "http/3", "tls": "TLSv1.3" },
  "checks": [
    { "id": "gateway-ping", "host": "gcp-gateway.rift.ai", "critical": true, "level": "ok",
      "medianMs": 228, "attempts": [{ "ok": true, "ms": 231 }, …] }
  ]
}
```

`level` is `ok`, `warn` or `fail`. A failed attempt carries `error` (`timeout` or `unreachable`) and the
browser's raw `message`. Browsers hide the real cause (`TypeError: Load failed` in Safari for DNS, TLS
and blocked requests alike), so read the attempt's `ms` alongside it:

| Pattern | Likely cause |
|---|---|
| `unreachable`, a few ms | Blocked before it left the device: content blocker, DNS filter returning 0.0.0.0 |
| `unreachable`, 50 ms – a few s | DNS failure, TLS failure or connection reset (VPN/firewall/ISP) |
| `timeout` (10 s) | Packets silently dropped — firewall, captive portal, very poor connection |
| every host fails | Device offline or a VPN routing everything into nothing |
| only analytics hosts fail | Ad/tracker blocking (NextDNS, AdGuard, Pi-hole, corporate DNS) |
`network` comes from Cloudflare's `/cdn-cgi/trace` (no IP address is stored).

## Limitations

- Requests use `no-cors`, so the page only learns that DNS, TLS and the connection succeeded — not the
  HTTP status. An HTTP error from a reachable server still counts as reachable.
- Safari applies its own content blockers and iCloud Private Relay; the app does not. VPNs and DNS
  profiles (NextDNS, AdGuard, corporate DNS) apply to both. A clean report therefore does not clear the
  app, but a failing one points at the network.
- It cannot see anything inside the app (Keychain, storage, Privy session, SDK state).
- The host list is hidden from the UI, not secret — it is readable in the page source.

## Running locally

```sh
npx serve .
```

## Deploying (GitHub Pages)

Deployed from your machine, no GitHub Actions. `deploy.sh` copies `index.html` (and nothing else) into a
fresh `gh-pages` branch and force-pushes it to the remote.

```sh
./deploy.sh          # pushes to origin
./deploy.sh upstream # or any other remote
```

One-time setup: add the GitHub remote, run `./deploy.sh` once so the branch exists, then
**Settings → Pages → Build and deployment → Source: Deploy from a branch → `gh-pages` / `(root)`**.

It deploys the working copy, so uncommitted edits to `index.html` go out too.

The page lands at `https://<org>.github.io/<repo>/`. GitHub Pages serves HTTPS, which the probes and
`navigator.clipboard` require. On a free plan the repo must be public for Pages; the page source (host
list included) is public either way once deployed.

Hosts are listed in `CHECKS` at the top of the script; keep them in sync with
`targets/*/env.production` and `targets/*/app.config.ts` in `rift-mobile-app`. Bump `REPORT_VERSION`
when the report shape changes.
