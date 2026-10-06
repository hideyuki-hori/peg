#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${PEG_SIGN_IDENTITY:-Peg Dev Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

ensure_identity() {
  if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "\"$IDENTITY\""; then
    return
  fi
  echo "署名用の証明書 '$IDENTITY' がないので作成します（パスワードの確認が出たらログインパスワードを入力してください）"
  local work
  work="$(mktemp -d)"
  cat > "$work/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$work/openssl.cnf" \
    -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
  openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
    -name "$IDENTITY" -passout pass:peg -out "$work/identity.p12"
  security import "$work/identity.p12" -k "$KEYCHAIN" -P peg -T /usr/bin/codesign >/dev/null
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$work/cert.pem"
  rm -rf "$work"
  if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "\"$IDENTITY\""; then
    echo "証明書を作成できませんでした" >&2
    exit 1
  fi
}

ensure_identity

swift build -c release

APP="dist/Peg.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Peg" "$APP/Contents/MacOS/Peg"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP"

echo "$APP"
