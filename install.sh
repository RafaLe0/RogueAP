#!/bin/bash

set -e

echo "[*] Installing airRecon..."

install -d /usr/local/bin
install -d /usr/local/lib/airrecon
install -d /usr/local/share/man/man1

install -m 755 bin/airrecon /usr/local/bin/airrecon
cp -r lib/* /usr/local/lib/airrecon/

install -m 644 man/airrecon.1 /usr/local/share/man/man1/

mandb >/dev/null 2>&1 || true

echo "[+] airRecon installed."
