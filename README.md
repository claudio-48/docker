# OASI Software – production-style Docker stack (example)

This directory contains a **production-style Docker Compose example**

It is meant as a **reference architecture** for real-world OpenACS installations.

---

## Design goals and use cases

This setup is designed to support:

* long-lived OpenACS installations
* multiple parallel instances on the same host
* testing different NaviServer / Tcl combinations against one OpenACS tree
* production-like deployments with externalized state
* clear separation between *binaries* and *site data*

---

## Core design principles

### Normalized internal filesystem layout

All containers operate on a **fixed internal directory structure**.
Host paths are introduced *only* via Docker volumes or bind mounts.

Inside the containers, the following paths are canonical:

| Purpose                  | Internal path                      |
| ------------------------ | ---------------------------------- |
| OpenACS server root      | `/var/www/openacs`                 |
| Configuration files      | `/var/www/openacs/etc`             |
| Logs                     | `/var/www/openacs/log`             |
| Managed TLS certificates | `/var/lib/naviserver/certificates` |
| Secrets                  | `/run/secrets`                     |

OpenACS and NaviServer configuration files **never reference host paths**.

---

### 1. Containers hold binaries, not state

All containers are **stateless**:

* OpenACS application code
* NaviServer binaries
* Postfix (mail relay)
* Mginx (reverse proxy)

All **stateful data** lives outside containers:

* OpenACS tree
* logs
* secrets
* database
* TLS certificates

This allows:

* easy upgrades
* simple backups
* reproducible rebuilds
* fast rollback

---

### 2. External OpenACS tree (site data)

The complete OpenACS installation is mounted from the host into the
canonical internal location:

```text
/var/www/openacs
```

The host path is provided via the stack-level variable:

```
hostroot
```

This enables:

* running multiple containers against the same code base
* comparing different NaviServer versions
* sharing a consistent layout between development and production

---

### 3. Database via Unix domain socket

PostgreSQL is accessed via a **Unix domain socket**, not TCP:

* no database port exposed
* lower latency
* reduced attack surface
* supports non-standard database ports

Socket path example on the host:

```text
/tmp/.s.PGSQL.<db_port>
```

The socket is mounted into containers that require database access.

---

### 4. IPv4 + IPv6 connectivity

The site is reachable via **both IPv4 and IPv6**.

Ports are explicitly bound to:

* one IPv4 address
* one IPv6 address

This makes dual-stack behavior explicit and testable.

---

### 5. Tailored NaviServer configuration

The NaviServer configuration file is **site-specific** and supports:

* multiple domain names
* multiple NaviServer servers
* internal loopback server
* custom module setup
* custom logging layout

The file provided here:

```text
config.tcl
```

is a **template / example**, not a production snapshot.

The variable `nsdconfig` is interpreted as a **relative filename** under:

```text
/var/www/openacs/etc/
```

---

### 6. TLS certificates (managed store)

TLS certificates are **always used** from the managed certificate store:

```text
/var/lib/naviserver/certificates/<hostname>.pem
```

#### Certificate seed (`certificate`)

The variable `certificate` specifies a **relative PEM filename** under:

```text
/var/www/openacs/certificates/
```

Example:

```text
certificate=oacs-a.pem
```

Seed lookup order:

1. `/var/www/openacs/certificates/<certificate>`
2. legacy fallback: `/var/www/openacs/etc/<certificate>`

If a readable seed certificate is found, it is copied into the managed
certificate store. The managed copy is then used by:

* Nginx (HTTPS)
* Postfix (SMTP TLS)

#### Managed vs. external certificates

By default, a writable Docker volume is mounted at:

```text
/var/lib/naviserver/certificates
```

This directory is owned by the container and is suitable for:

* generated certificates
* copied seed certificates
* future automated renewal

If `certificatesdir` is set to a host path, certificates are treated as
**externally managed**. In that case, no automatic creation or renewal
is assumed.
   
---

## 7. Optional memory optimization

This setup supports preloading Google tcmalloc:

```sh
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
```

In combination with:

* `SYSTEM_MALLOC` Tcl settings
* NaviServer/module configuration

this can significantly reduce memory footprint under load.

---

## Container overview

### oacs-a oacs-b alter-dev

OpenACS / NaviServer container.

* exposes HTTP 
* uses a site-specific NaviServer config
* connects to PostgreSQL
* optionally uses tcmalloc

---

### mailrelay

Postfix-based outgoing SMTP relay.

* implements a sender dependent relay strategy
* reads TLS certificate from the managed certificate store

---

### nginx

Nginx reverse proxy server

* decodes the encrypted SSL content 
* routes the requests to the openacs instances via http

---

## Stack-level environment variables

These variables act as **deployment knobs** and are typically set via:

* `.env` files
* shell environment

---

### Required variables

| Variable   | Description                                   |
| ---------- | --------------------------------------------- |
| `hostname` | DNS name of the site (e.g. `openacs.org`)     |
| `hostroot` | Host path or volume name for the OpenACS tree |
| `logdir`   | Host path or volume name for logs             |

---

### Optional variables

#### NaviServer

| Variable                | Default | Purpose                                         |
| ----------------------- | ------- | ----------------------------------------------- |
| `nsdconfig`             | empty   | Relative filename under `/var/www/openacs/etc/` |
| `internal_loopbackport` | `8888`  | Internal loopback server port                   |

---

#### Networking

| Variable      | Default     | Purpose             |
| ------------- | ----------- | ------------------- |
| `ipaddress`   | `127.0.0.1` | IPv4 bind address   |
| `httpport`    | auto        | External HTTP port  |
| `httpsport`   | auto        | External HTTPS port |

---

#### TLS / certificates

| Variable      | Default           | Purpose               |
| ------------- | ----------------- | --------------------- |
| `certificate` | `${hostname}.pem` | Relative PEM filename |

---

#### Database

| Variable  | Default     | Purpose                      |
| --------- | ----------- | ---------------------------- |
| `db_user` | `openacs`   | Database user                |
| `db_host` | `localhost` | Database host (socket-based) |
| `db_port` | `5432`      | Database port (socket name)  |

Secrets are always file-based and external.

---

#### Performance / tuning

| Variable      | Default       | Purpose               |
| ------------- | ------------- | --------------------- |
| `LD_PRELOAD`  | empty         | Preload tcmalloc      |
| `system_pkgs` | `imagemagick` | Extra system packages |

---

## Secrets

Secrets are **not stored in this repository**.

Expected files (mounted into `/run/secrets`):

```text
psql_password
cluster_secret
parameter_secret
```

They are read by startup scripts and never embedded into images.

---

## Files in this directory

* `docker-compose.yml`
  Full production-style stack definition

* `config.tcl`
  NaviServer configuration

* `.env`
  Stack-level configuration

To get started:

Adjust values to match your host paths, IP addresses, and site name.
No secrets are stored in `.env`.

---

## When to use this example

Use this setup if you want:

* a production-grade OpenACS deployment
* maximum flexibility for upgrades and testing
* strong separation between infrastructure and application state

---

## Final notes

This example reflects **operational experience**, not minimalism.
It is intended as a **reference architecture**, not a copy-and-paste recipe.

---

## License

This project is subject to the terms of the Mozilla Public License, v. 2.0.
Copyright © 2025 Gustaf Neumann


