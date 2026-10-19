#!/usr/bin/env bash
# Prints the name of a local code-signing identity, creating it in the login keychain on first use.
#
# Why: macOS ties the Accessibility permission to the app's code signature. An ad-hoc signature
# changes on every build, so each reinstall silently loses the permission. A stable self-signed
# certificate keeps the signature's identity the same across builds, so you grant it once.
set -euo pipefail

NAME="rishabhwm local signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "$NAME"
    exit 0
fi

command -v openssl >/dev/null || { echo "openssl is required to create the signing certificate" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PASS=rishabhwm

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" >/dev/null 2>&1
# 3DES/SHA1 PKCS#12: the encryption macOS `security import` understands.
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout "pass:$PASS" -out "$WORK/identity.p12"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "created code-signing certificate \"$NAME\" in the login keychain" >&2
echo "$NAME"
