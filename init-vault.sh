#! /bin/bash

# Initialize Hashicorp vault for besu encrypted rocksdb plugin
# Assuming Hashicorp vault is running in docker and jq utility is available to parse json output

# exit when any command fails
set -e

echo "Init Hashicorp vault"
VAULT_HOST="https://127.0.0.1:8200/v1"
INIT_OUT=$(curl -s -k -X PUT \
	-d '{"secret_shares": 1, "secret_threshold": 1}' "$VAULT_HOST/sys/init" | jq)

VAULT_TOKEN=$(echo "$INIT_OUT" | jq --raw-output '.root_token')
VAULT_KEY=$(echo "$INIT_OUT" | jq --raw-output '.keys_base64[0]')

echo "Root Token: $VAULT_TOKEN"
echo "Unseal Key: $VAULT_KEY"

## Unseal ##
echo "Unsealing Hashicorp Vault"
curl -s -k -X PUT -d "{\"key\": \"$VAULT_KEY\"}" "$VAULT_HOST/sys/unseal" | jq

## Enable KV-v2 /secret mount
echo "Enable kv-v2 secret engine path at /secret"
curl -s -k -X POST -H "X-Vault-Token: $VAULT_TOKEN" \
	-d '{"type": "kv", "options": {"version": "2"}}' "$VAULT_HOST/sys/mounts/secret" | jq

## Generate a random 32 bytes keys
echo "Generating random key"
KEY=$(openssl rand -hex 32)
echo "Encryption Key: $KEY"

# Place DB Encryption key
echo "Create key in vault"
curl -s -k -X POST -H "X-Vault-Token: $VAULT_TOKEN" -d "{\"data\": {\"value\": "\""$KEY"\""}}" \
	"$VAULT_HOST/secret/data/DBEncryptionKey" | jq

# Obtain DB Encryption key
echo "Reading data from vault"
curl -s -k -X GET -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_HOST/secret/data/DBEncryptionKey" |
	jq '.data.data'

# Create hashicorp_config.toml file with root token

echo "Writing hashicorp_config.toml"
cat <<EOF >./hashicorp_config.toml
hashicorp.serverHost="localhost"
hashicorp.serverPort=8200
hashicorp.token="$VAULT_TOKEN"
hashicorp.keyPath="/v1/secret/data/DBEncryptionKey"
hashicorp.timeout=30
hashicorp.tlsEnable=true
hashicorp.tlsVerifyHost=true
hashicorp.tlsTrustStoreType="PEM"
hashicorp.tlsTrustStorePath="/tmp/vault/ssl/vault.crt"
EOF
