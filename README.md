# neofire Core System

Bestellsystem für Produkte, Termine, Vermietung und Abos – selbst gehostet mit Docker. Mehr unter [neofire.de](https://www.neofire.de).

```
ghcr.io/neofire-core-system/core:1
```

## Schnellstart

```bash
cp .env.example .env
docker compose up -d
```

Beim ersten Start wartet der Container auf die Datenbank und richtet den Shop automatisch ein. Danach ist er unter `SHOP_URL` erreichbar, die Verwaltung unter `SHOP_URL/admin`.

## Installation bei mittwald (mStudio)

neofire Core läuft im mittwald mStudio als Container-Stack (neofire Core + MariaDB). Eingerichtet wird es per Knopfdruck über GitHub Actions.

1. **Projekt im mStudio anlegen** (oder ein bestehendes nehmen) und unter *Container* die ID des Standard-Stacks kopieren.
2. **API-Token erstellen:** mStudio › Profil › API-Tokens › neues Token mit Schreibrechten.
3. **Dieses Repository forken** (oben rechts *Fork*).
4. Im Fork unter *Settings › Secrets and variables › Actions* eintragen:
   - Secrets: `MITTWALD_API_TOKEN` (das Token), `NEOFIRE_DB_PASSWORD` (frei wählbar, lang), `NEOFIRE_ADMIN_PASSWORD` (Passwort für die Verwaltung)
   - Variable: `MITTWALD_STACK_ID` (die Stack-ID aus Schritt 1)
5. **Actions › Installation bei mittwald › Run workflow:** Shop-Adresse, Shopname, E-Mail, Firma und Anschrift eintragen, Bedingungen bestätigen, *Run workflow*.
6. Im mStudio unter *Domains* die Shop-Adresse auf den Container **neofire**, Port **80**, zeigen lassen.

Nach 1–2 Minuten ist der Shop unter der Adresse erreichbar, die Verwaltung unter `/admin`. Ein erneuter Lauf des Workflows aktualisiert den Kern; die Datenbank wird dabei nicht neu erstellt. Daten liegen in den Stack-Volumes `neofire_data` und `mariadb_data` und sind in der Projektsicherung von mittwald enthalten.

Die Vorlage liegt in [`mittwald/stack.yaml`](mittwald/stack.yaml), der Ablauf in [`.github/workflows/deploy-mittwald.yml`](.github/workflows/deploy-mittwald.yml).

## Ohne Docker (Webserver mit PHP und MySQL)

Im leeren Web-Verzeichnis per SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/neofire-core-system/docker/main/install.sh -o /tmp/neofire-install.sh
bash /tmp/neofire-install.sh
```

Das Skript lädt die aktuelle Version von neofire.de, fragt Datenbank, Shop- und Betreiberdaten ab und richtet den Shop ein.

## Umgebungsvariablen

| Variable | Pflicht | Bedeutung |
|---|---|---|
| `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` | ja | Zugang zur MariaDB/MySQL-Datenbank |
| `SHOP_URL` | ja | öffentliche Adresse des Shops, z. B. `https://shop.example.de` |
| `SHOP_EMAIL` | ja | E-Mail-Adresse des Shops |
| `ADMIN_USER`, `ADMIN_EMAIL`, `ADMIN_PASS` | Passwort ja | erster Zugang zur Verwaltung |
| `COMPANY`, `STREET`, `POSTCODE`, `CITY` | ja | Betreiberangaben (Impressum, Belege) |
| `ACCEPT_TERMS` | ja | `1` = Lizenzbedingungen, AGB und Datenschutz von neofire akzeptiert |
| `NEOFIRE_AUTO_INSTALL` | nein | `0` schaltet die automatische Einrichtung ab |
| `NEOFIRE_AUTO_UPDATE` | nein | `0` verhindert, dass ein neues Image den Kern (`vendor/neofire`) aktualisiert |
| `NEOFIRE_CRON` | nein | `0` schaltet die eingebaute Cron-Schleife ab |

Alle Daten (Einstellungen, Medien, Dokumente, Erweiterungen) liegen im Volume `/var/www/html`. Ein neues Image aktualisiert nur den Kern unter `vendor/neofire`.

## Lizenz

neofire Core ist proprietäre Software. Es gelten die [AGB](https://www.neofire.de/agb) und die [Datenschutzerklärung](https://www.neofire.de/datenschutz) von neofire. Dieses Repository enthält nur die Bauanleitung des Images; der Shop wird beim Bau aus dem offiziellen Paket geladen.
