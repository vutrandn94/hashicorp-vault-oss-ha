#!/bin/bash

set -e

CA_NAME="vault-root-ca"
CERT_NAME="vault-server"
DAYS_CA=7300      # expire 20 years
DAYS_CERT=3650    # exipre 10 years
COMMON_NAME="*.vault.local"
SAN_DNS_1="vault-1.vault.local"
SAN_DNS_2="vault-2.vault.local"
SAN_DNS_3="vault-3.vault.local"
SAN_DNS_4="vault.local"

OUTPUT_DIR="./vault-certs"
mkdir -p "$OUTPUT_DIR"

echo "Create CA (Root Certificate Authority)..."

openssl genrsa -out "$OUTPUT_DIR/$CA_NAME.key.pem" 4096

openssl req -x509 -new -nodes -key "$OUTPUT_DIR/$CA_NAME.key.pem" \
  -sha256 -days $DAYS_CA -out "$OUTPUT_DIR/$CA_NAME.cert.pem" \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Vault CA/CN=Vault Root CA"

echo "Create certificate + key for Vault Server..."

openssl genrsa -out "$OUTPUT_DIR/$CERT_NAME.key.pem" 2048

cat > "$OUTPUT_DIR/cert.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no
req_extensions = v3_req

[req_distinguished_name]
CN = $COMMON_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SAN_DNS_1
DNS.2 = $SAN_DNS_2
DNS.3 = $SAN_DNS_3
DNS.4 = $SAN_DNS_4
EOF

openssl req -new -key "$OUTPUT_DIR/$CERT_NAME.key.pem" \
  -out "$OUTPUT_DIR/$CERT_NAME.csr.pem" \
  -config "$OUTPUT_DIR/cert.cnf"

openssl x509 -req -in "$OUTPUT_DIR/$CERT_NAME.csr.pem" \
  -CA "$OUTPUT_DIR/$CA_NAME.cert.pem" \
  -CAkey "$OUTPUT_DIR/$CA_NAME.key.pem" \
  -CAcreateserial \
  -out "$OUTPUT_DIR/$CERT_NAME.cert.pem" \
  -days $DAYS_CERT -sha256 \
  -extensions v3_req \
  -extfile "$OUTPUT_DIR/cert.cnf"

echo "Success. Files certificate storage in $OUTPUT_DIR:"
ls -l "$OUTPUT_DIR"
