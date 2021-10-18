#!/bin/bash
set -e #exit if any command fails

# Run Hashicorp Vault in server mode with inmem storage and TLS enabled


VAULT_MOUNT="/tmp/vault"
mkdir -p "$VAULT_MOUNT/ssl"

#Generate SSL certificates
echo "Generating SSL certificates..."
## Create following file req.conf
cat <<EOF > ./req.conf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = AU
ST = QLD
L = Brisbane
O = PegaSys
OU = Prod Dev
CN = localhost
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout "$VAULT_MOUNT/ssl/vault.key" \
 -out "$VAULT_MOUNT/ssl/vault.crt" -config ./req.conf -extensions 'v3_req'

# Pull docker image
echo "Pulling vault docker image"
docker pull vault:1.2.3 

# Run Vault in docker in server mode
echo "Running vault in server mode"
VAULT_LOCAL_CONFIG=$(printf '%s' \
"{\"storage\": {\"inmem\":{}}, \"default_lease_ttl\": \"168h\", \
 \"max_lease_ttl\": \"720h\", \"listener\": {\"tcp\": {\"address\": \"0.0.0.0:8200\", \
  \"tls_min_version\": \"tls12\", \"tls_cert_file\": \"/vault/config/ssl/vault.crt\", \
  \"tls_key_file\": \"/vault/config/ssl/vault.key\"}}}")

docker run --rm --cap-add=IPC_LOCK -p8200:8200 --name=test-vault \
 -v "$VAULT_MOUNT:/vault/config" \
 -e 'VAULT_SKIP_VERIFY=true' \
 -e "VAULT_LOCAL_CONFIG=$VAULT_LOCAL_CONFIG" \
 vault:1.2.3 server
