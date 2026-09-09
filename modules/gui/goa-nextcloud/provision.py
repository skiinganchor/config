#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path
from typing import Final
from urllib.parse import urlparse, urlunparse

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")

from gi.repository import Gio, GLib


BUS_NAME: Final = "org.gnome.OnlineAccounts"
ROOT_PATH: Final = "/org/gnome/OnlineAccounts"
MANAGER_PATH: Final = "/org/gnome/OnlineAccounts/Manager"
OBJECT_MANAGER_IFACE: Final = "org.freedesktop.DBus.ObjectManager"
MANAGER_IFACE: Final = "org.gnome.OnlineAccounts.Manager"
ACCOUNT_IFACE: Final = "org.gnome.OnlineAccounts.Account"
PROVIDER: Final = "owncloud"


class ProvisionError(Exception):
    pass


def normalized_server_address(value: str) -> tuple[str, str]:
    parsed = urlparse(value)
    if parsed.scheme != "https" or parsed.hostname is None or parsed.username is not None:
        raise ProvisionError(f"Invalid Nextcloud server address: {value}")
    if parsed.query or parsed.fragment or parsed.path.endswith("/remote.php/dav") or parsed.path.endswith("/remote.php/webdav"):
        raise ProvisionError(f"Nextcloud server address must be a base address: {value}")
    path = parsed.path.rstrip("/")
    canonical = urlunparse(("https", parsed.netloc, path, "", "", ""))
    return canonical, parsed.hostname


def account_properties() -> dict[str, dict[str, dict[str, GLib.Variant]]]:
    object_manager = Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.NONE,
        None,
        BUS_NAME,
        ROOT_PATH,
        OBJECT_MANAGER_IFACE,
        None,
    )
    return object_manager.call_sync(
        "GetManagedObjects", None, Gio.DBusCallFlags.NONE, -1, None
    ).unpack()[0]


def account_exists(username: str, presentation_identity: str) -> bool:
    for interfaces in account_properties().values():
        account = interfaces.get(ACCOUNT_IFACE)
        if account is None:
            continue
        provider = account["ProviderType"].unpack()
        identity = account["Identity"].unpack()
        presentation = account["PresentationIdentity"].unpack()
        if provider == PROVIDER and identity == username and presentation == presentation_identity:
            return True
    return False


def provision_account(account: dict[str, str]) -> None:
    base_url, host = normalized_server_address(account["serverAddress"])
    username = account["username"]
    presentation_identity = username if "@" in username else f"{username}@{host}"
    if account_exists(username, presentation_identity):
        print(f"Nextcloud GOA account already exists: {presentation_identity}")
        return

    password = Path(account["secretPath"]).read_text().removesuffix("\n").removesuffix("\r")
    if not password:
        raise ProvisionError(f"Nextcloud app password is empty for {presentation_identity}")

    credentials = { "password": GLib.Variant("s", password) }
    dav_uri = f"{base_url}/remote.php/dav"
    details = {
        "Uri": f"{base_url}/remote.php/webdav",
        "FilesEnabled": "true",
        "CalendarEnabled": "true",
        "CalDavUri": dav_uri,
        "ContactsEnabled": "true",
        "CardDavUri": dav_uri,
        "AcceptSslErrors": "false",
    }
    parameters = GLib.Variant(
        "(sssa{sv}a{ss})",
        (PROVIDER, username, presentation_identity, credentials, details),
    )
    manager = Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.NONE,
        None,
        BUS_NAME,
        MANAGER_PATH,
        MANAGER_IFACE,
        None,
    )
    object_path = manager.call_sync(
        "AddAccount", parameters, Gio.DBusCallFlags.NONE, -1, None
    ).unpack()[0]
    print(f"Created Nextcloud GOA account {presentation_identity}: {object_path}")


def main() -> int:
    manifest_path = os.environ.get("GOA_ACCOUNTS_FILE")
    if manifest_path is None:
        raise ProvisionError("GOA_ACCOUNTS_FILE is required")
    accounts = json.loads(Path(manifest_path).read_text())
    if not isinstance(accounts, list):
        raise ProvisionError("GOA account manifest must be a list")
    for account in accounts:
        if not isinstance(account, dict) or not all(isinstance(account.get(key), str) for key in [ "serverAddress", "username", "secretPath" ]):
            raise ProvisionError("GOA account manifest contains an invalid account")
        provision_account(account)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ProvisionError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from None
