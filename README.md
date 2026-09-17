# auraPanel by auraOne

**auraPanel** is a modern Linux server control panel for Debian and Ubuntu. From one interface it runs websites and applications (WordPress and PHP, Node.js, Python, static sites, Docker Compose stacks and reverse proxies), manages PostgreSQL and MariaDB databases, issues and renews HTTPS certificates automatically, schedules backups, and operates the server underneath — on infrastructure you own.

It is made by [auraOne](https://goaura.one), the product line of Garuda Consulting Ltd. The official website is **[aurapanel.net](https://aurapanel.net)**.

## What this repository is

The **release channel**: `.deb` packages for amd64 and arm64, the static `aurapaneld` and `auradb` binaries, and a `SHA256SUMS` file with its Ed25519 signature for every release. The source is developed in a private repository; the installer and the panel's built-in self-update both download from here.

## Install

One command on a fresh Debian 12/13 or Ubuntu 22.04–26.04 server (x86-64 or ARM64):

```bash
curl -fsSL https://aurapanel.net/install.sh | bash
```

`https://aurapanel.net/install.sh` is the official installer URL; `https://aurapanel.goaura.one/installer.sh` serves the same file. Requirements and what the installer changes: <https://aurapanel.net/download>

New installs start a 30-day free trial with no card required. One licence covers one server and everything you run on it: <https://aurapanel.net/pricing>

## Verifying a release

Every release ships `SHA256SUMS` and `SHA256SUMS.sig` (Ed25519). The panel verifies the signature before applying an update and refuses builds that fail verification. To check a download yourself, compare its SHA-256 against `SHA256SUMS` from the same release.

## Links

- Website — <https://aurapanel.net>
- Features — <https://aurapanel.net/features>
- Install — <https://aurapanel.net/download>
- Documentation and `apcli` reference — <https://aurapanel.net/docs>
- Security — <https://aurapanel.net/security>
- Pricing — <https://aurapanel.net/pricing>
- About auraPanel and auraOne — <https://aurapanel.net/about>
- Live demo — <https://goaura.one/demo>
- Accounts and customer portal — <https://goaura.one/portal>
