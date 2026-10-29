# finance-deployer

GitHub Actions workflows that deploy self-hosted apps to Hostinger shared hosting.

## Firefly III

`.github/workflows/deploy.yml` deploys [Firefly III](https://github.com/firefly-iii/firefly-iii).

App, database, and FTP secrets use a `FIREFLY_` prefix. Recreate each renamed secret under the new name before the next Firefly deploy. The old names are no longer read.

| Old name | New name |
| --- | --- |
| `APP_KEY` | `FIREFLY_APP_KEY` |
| `APP_URL` | `FIREFLY_APP_URL` |
| `SITE_OWNER` | `FIREFLY_SITE_OWNER` |
| `DB_CONNECTION` | `FIREFLY_DB_CONNECTION` |
| `DB_HOST` | `FIREFLY_DB_HOST` |
| `DB_PORT` | `FIREFLY_DB_PORT` |
| `DB_DATABASE` | `FIREFLY_DB_DATABASE` |
| `DB_USERNAME` | `FIREFLY_DB_USERNAME` |
| `DB_PASSWORD` | `FIREFLY_DB_PASSWORD` |
| `FTP_SERVER` | `FIREFLY_FTP_SERVER` |
| `FTP_USERNAME` | `FIREFLY_FTP_USERNAME` |
| `FTP_PASSWORD` | `FIREFLY_FTP_PASSWORD` |

These SSH secrets stay unchanged: `SSH_REMOTE_HOST`, `SSH_REMOTE_USER`, `SSH_REMOTE_PASSWORD`, `SSH_REMOTE_PORT`, `SSH_REMOTE_PATH`. `GITHUB_TOKEN` is still the automatic Actions token.

## Investbrain

`.github/workflows/deploy-investbrain.yml` deploys the latest [Investbrain](https://github.com/investbrainapp/investbrain) release to `https://investments.alebatistella.com`.

1. The workflow runs only from **Run workflow** (`workflow_dispatch`).
2. It does not run on push, pull request, or a schedule.
3. Merging this repository does not deploy.

Investbrain v1.3.1 is Laravel 13. Its lockfile uses Symfony 8.1, which requires PHP 8.4.1 or newer. The release is source, not a built zip, so the workflow installs Composer packages, builds the Vite assets, then uploads one zip. FTP and SSH match the Firefly workflow: upload the zip, unzip on the server, then run Artisan there.

### Why the secrets are separate

1. Every value for this app is an `INVESTBRAIN_` secret.
2. The Firefly workflow reads `FIREFLY_FTP_*`, `FIREFLY_APP_*`, `FIREFLY_DB_*`, `FIREFLY_SITE_OWNER`, and the unprefixed `SSH_REMOTE_*` secrets.
3. Those secrets are the finance site. Its FTP login lands in the finance document root, and `SSH_REMOTE_PATH` is that directory.
4. Reusing them would unpack Investbrain on top of Firefly.
5. The Hostinger SSH host, user, password, and port are often one account for both sites. Copy those four into `INVESTBRAIN_SSH_REMOTE_HOST`, `INVESTBRAIN_SSH_REMOTE_USER`, `INVESTBRAIN_SSH_REMOTE_PASSWORD`, and `INVESTBRAIN_SSH_REMOTE_PORT`.
6. Use a different path, a different FTP account locked to this site's `public_html`, and a different database.
7. The Firefly workflow never reads `INVESTBRAIN_` secrets.
8. `GITHUB_TOKEN` is the automatic Actions token. Do not create it.
9. A secret value must not contain a single quote or a newline. The writer stores values in single quotes so `$`, spaces, and `#` stay literal.

### 1. Create the website and database

1. In hPanel, add the subdomain `investments` on `alebatistella.com`.
2. Leave the document root at `domains/investments.alebatistella.com/public_html`. The workflow's root `.htaccess` rewrites requests into `public/`.
3. Open PHP configuration for this site and select PHP **8.4**. Confirm the CLI reports 8.4.1 or newer. PHP 8.3 cannot install this lockfile.
4. Enable `bcmath`, `curl`, `fileinfo`, `gd`, `intl`, `mbstring`, `openssl`, `pdo_mysql`, `sodium`, and `zip`.
5. Install the free SSL certificate and turn on Force HTTPS.
6. Create a MySQL database and user. Record the host, port, database name, user, and password from hPanel.
7. Turn on SSH access and record the host, port, user, and password.
8. Create an FTP account whose home is this site's `public_html`, not the finance site and not the account home.
9. The zip is uploaded to the FTP home and unzipped in `INVESTBRAIN_SSH_REMOTE_PATH`. Those two directories must be the same folder.
10. Over SSH, run `/opt/alt/php84/usr/bin/php -v` and `/opt/alt/php84/usr/bin/php -m`.
11. The version must be 8.4.1 or newer. The default `php` command is often older. `intl` and `gd` must appear in the module list. Put that binary path in `INVESTBRAIN_PHP_BIN`.
12. Set `memory_limit` to `512M` for this site. The first migration imports a market-data file and fetches exchange rates.

### 2. Add the GitHub secrets

In GitHub: Settings → Secrets and variables → Actions → New repository secret.

Generate `INVESTBRAIN_APP_KEY` once and keep it. A new key makes existing sessions and two-factor secrets unreadable.

```bash
php artisan key:generate --show
```

With no PHP install:

```bash
printf 'base64:%s\n' "$(openssl rand -base64 32)"
```

Store the whole `base64:...` value.

Required secrets:

| Secret | What it holds |
| --- | --- |
| `INVESTBRAIN_FTP_SERVER` | FTP host for this site |
| `INVESTBRAIN_FTP_USERNAME` | FTP user locked to this site's `public_html` |
| `INVESTBRAIN_FTP_PASSWORD` | That FTP user's password |
| `INVESTBRAIN_SSH_REMOTE_HOST` | SSH host. Often the same value as Firefly's `SSH_REMOTE_HOST` |
| `INVESTBRAIN_SSH_REMOTE_USER` | SSH user. Often the same account as Firefly |
| `INVESTBRAIN_SSH_REMOTE_PASSWORD` | SSH password |
| `INVESTBRAIN_SSH_REMOTE_PORT` | SSH port, often `65002` |
| `INVESTBRAIN_SSH_REMOTE_PATH` | Absolute path of this site's `public_html` |
| `INVESTBRAIN_PHP_BIN` | Absolute PHP 8.4.1+ CLI, usually `/opt/alt/php84/usr/bin/php` |
| `INVESTBRAIN_APP_NAME` | `Investbrain` |
| `INVESTBRAIN_APP_ENV` | `production` |
| `INVESTBRAIN_APP_KEY` | Laravel key, `base64:...` |
| `INVESTBRAIN_APP_DEBUG` | `false` |
| `INVESTBRAIN_APP_URL` | `https://investments.alebatistella.com` |
| `INVESTBRAIN_ASSET_URL` | `https://investments.alebatistella.com` |
| `INVESTBRAIN_APP_TIMEZONE` | `America/Sao_Paulo` (same zone as the Firefly deploy; any PHP timezone is valid) |
| `INVESTBRAIN_APP_LOCALE` | `en`, `es`, or `fr` (the translation files in the current release) |
| `INVESTBRAIN_SELF_HOSTED` | `true` |
| `INVESTBRAIN_REGISTRATION_ENABLED` | `true` for the first deploy, then `false` |
| `INVESTBRAIN_AI_CHAT_ENABLED` | `false` |
| `INVESTBRAIN_LOG_CHANNEL` | `stack` |
| `INVESTBRAIN_LOG_LEVEL` | `error` |
| `INVESTBRAIN_FILESYSTEM_DISK` | `local` |
| `INVESTBRAIN_SESSION_DRIVER` | `file` |
| `INVESTBRAIN_QUEUE_CONNECTION` | `sync` |
| `INVESTBRAIN_CACHE_STORE` | `file` |
| `INVESTBRAIN_DB_CONNECTION` | `mysql` (or `mariadb` if the JSON column default fails) |
| `INVESTBRAIN_DB_HOST` | Database host from hPanel, often `localhost` |
| `INVESTBRAIN_DB_PORT` | `3306` |
| `INVESTBRAIN_DB_DATABASE` | Database name from hPanel |
| `INVESTBRAIN_DB_USERNAME` | Database user from hPanel |
| `INVESTBRAIN_DB_PASSWORD` | Database password from hPanel |
| `INVESTBRAIN_MARKET_DATA_PROVIDER` | `yahoo` (no API key). A comma-separated list is the fallback order, for example `yahoo,alphavantage` |
| `INVESTBRAIN_MARKET_DATA_REFRESH` | `30` (minutes) |
| `INVESTBRAIN_BASE_CURRENCY` | 3-letter code, such as `USD` or `BRL` |
| `INVESTBRAIN_MAIL_MAILER` | `log` or `smtp` |
| `INVESTBRAIN_MAIL_FROM_ADDRESS` | A mailbox you control |
| `INVESTBRAIN_MAIL_FROM_NAME` | `Investbrain` |

Optional secrets. Leave them unset to keep the upstream default.

| Secret | What it holds |
| --- | --- |
| `INVESTBRAIN_DAILY_CHANGE_TIME` | Snapshot time, `HH:MM`. Unset means `23:00` in `INVESTBRAIN_APP_TIMEZONE` |
| `INVESTBRAIN_ALPHAVANTAGE_API_KEY` | Alpha Vantage key, when that provider is in the list |
| `INVESTBRAIN_FINNHUB_API_KEY` | Finnhub key |
| `INVESTBRAIN_ALPACA_API_KEY` | Alpaca key |
| `INVESTBRAIN_ALPACA_API_SECRET` | Alpaca secret |
| `INVESTBRAIN_TWELVEDATA_API_SECRET` | Twelve Data secret |
| `INVESTBRAIN_CHAT_PROVIDER` | AI provider, only when chat is enabled |
| `INVESTBRAIN_CHAT_MODEL` | Model name for that provider |
| `INVESTBRAIN_OPENAI_API_KEY` | OpenAI key |
| `INVESTBRAIN_MAIL_HOST` | SMTP host. Required when the mailer is `smtp`. Hostinger usually shows `smtp.hostinger.com` |
| `INVESTBRAIN_MAIL_PORT` | SMTP port. Required for `smtp`. Hostinger usually uses `465` |
| `INVESTBRAIN_MAIL_USERNAME` | SMTP username. Required for `smtp` |
| `INVESTBRAIN_MAIL_PASSWORD` | SMTP password. Required for `smtp` |
| `INVESTBRAIN_MAIL_ENCRYPTION` | `ssl` for port 465. Unset uses Laravel's `tls` default |

`INVESTBRAIN_MAIL_MAILER=log` writes mail to `storage/logs/laravel.log`. Registration still requires a verified email. Use `smtp` before creating the first user, or copy the verification link out of that log.

### 3. Run the first deploy

1. Add the secrets. Leave `INVESTBRAIN_REGISTRATION_ENABLED` as `true`.
2. Open Actions → Deploy Investbrain → Run workflow.
3. When it finishes, open `https://investments.alebatistella.com/register` and create the account.
4. Open the verification link from the mailbox, or from `storage/logs/laravel.log` when the mailer is `log`.
5. Set `INVESTBRAIN_REGISTRATION_ENABLED` to `false` and run the workflow again.

The deploy downloads the latest release tag, runs `composer install --no-dev --no-scripts`, runs `npm ci` and `npm run build`, writes `.env`, runs `php artisan package:discover` and `php artisan filament:upgrade`, uploads the zip over FTP, unzips it over SSH, then runs `migrate --force`, `storage:link`, `config:cache`, `route:cache`, and `event:cache`.

### 4. Cron for the scheduler

In hPanel: Advanced → Cron Jobs → every minute. Replace the path and the PHP binary with your two secrets:

```bash
* * * * * cd /ABSOLUTE/PUBLIC_HTML && /opt/alt/php84/usr/bin/php artisan schedule:run >> storage/logs/scheduler.log 2>&1
```

1. Weekdays, every minute: the market-data command runs. Each symbol updates only when its quote is older than `INVESTBRAIN_MARKET_DATA_REFRESH` minutes.
2. Weekdays at `DAILY_CHANGE_TIME` (default `23:00` in the app timezone): portfolio snapshot.
3. Monday, Wednesday, and Friday: dividends.
4. Weekly: splits.
5. Daily: currency rates.
6. Yearly: holding reconciliation.

There is no queue worker. `sync` runs queued work inside the web request or this cron process. A large import can hit `max_execution_time`. Raise that limit in PHP configuration if an import stops halfway. Delayed jobs run immediately, because the sync driver does not wait.

### Shared hosting limits

1. The site PHP and `INVESTBRAIN_PHP_BIN` must be PHP 8.4.1 or newer. The v1.3.1 lockfile pulls Symfony 8.1, which refuses PHP 8.3.
2. This plan is PHP and MySQL/MariaDB. Investbrain v1.2.0 said official MySQL support was dropped and recommended Postgres. v1.3.1 still ships the MySQL driver, fulltext indexes, and a MySQL branch in the multi-currency migration. This workflow uses that path. A later release can remove it, and `migrate` will then fail.
3. If `migrate` fails on the `options` JSON default, set `INVESTBRAIN_DB_CONNECTION` to `mariadb` and run the workflow again.
4. There is no Redis. Session and cache are files. The queue is `sync`. This release has no `jobs`, `sessions`, or `cache` tables.
5. The first migration seeds currencies, imports `database/seeders/market_data_seed.csv`, and calls Frankfurter (`https://api.frankfurter.app`) for today's rates. The server needs outbound HTTPS. The SSH step allows 30 minutes.
6. Yahoo Finance needs no key and can refuse a shared-hosting IP. If quotes stay empty, set another provider and its key, then run the workflow again.
7. Each run overwrites application files and `.env`, and leaves `storage/` and the database in place. Files removed upstream stay on disk, same as the Firefly unzip.
8. AI chat stays off unless `INVESTBRAIN_AI_CHAT_ENABLED` is `true` and a provider key is set. This plan cannot run a local Ollama server.
9. The FTP account and `INVESTBRAIN_SSH_REMOTE_PATH` must be this site. Pointing them at the finance site overwrites Firefly.
