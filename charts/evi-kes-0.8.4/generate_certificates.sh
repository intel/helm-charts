#!/bin/sh

mkdir -p pki
cd pki

# Root CA
openssl genrsa -out "root-ca.key" 4096
openssl req -new -key "root-ca.key" -out "root-ca.csr" -sha512 \
        -subj '/C=US/ST=CA/L=China/O=Hce/CN=CA'
cat > "root-ca.conf" <<EOF
[root_ca]
basicConstraints = critical,CA:TRUE,pathlen:1
keyUsage = critical, nonRepudiation, cRLSign, keyCertSign
subjectKeyIdentifier=hash
EOF

openssl x509 -req -days 3650 -in "root-ca.csr" -signkey "root-ca.key" -sha512 \
        -out "root-ca.crt" -extfile "root-ca.conf" -extensions root_ca

# Vault Certificates
openssl ecparam -genkey -name prime256v1 | openssl ec -out vault-server.key

openssl req -new -key "vault-server.key" -out "vault-server.csr" -sha384 \
        -subj '/C=US/ST=CA/L=China/O=Hce/CN=vault.dev.svc.cluster.local'

cat > "vault-crt.conf" <<EOF
[vault_server]
authorityKeyIdentifier=keyid,issuer
basicConstraints = critical,CA:FALSE
extendedKeyUsage=serverAuth,clientAuth
keyUsage = critical, digitalSignature, keyEncipherment
subjectAltName = DNS:vault.dev.svc.cluster.local, IP:127.0.0.1
subjectKeyIdentifier=hash
EOF

openssl x509 -req -days 365 -in "vault-server.csr" -CA "root-ca.crt" -CAkey "root-ca.key" -CAcreateserial -out "vault-server.crt" -extfile "vault-crt.conf" -extensions vault_server

# KES MinIO Certificates

openssl ecparam -genkey -name prime256v1 | openssl ec -out private.key

openssl req -new  -key "private.key" -out "public.csr" -sha384 \
        -subj '/C=US/ST=CA/L=China/O=Hce/CN=service'

cat > "minio-crt.conf" <<EOF
[minio_server]
authorityKeyIdentifier = keyid,issuer
basicConstraints = critical,CA:FALSE
extendedKeyUsage=serverAuth,clientAuth
keyUsage = critical, digitalSignature, keyEncipherment
subjectAltName = DNS:*.minio-hl-svc.minio.svc.cluster.local, DNS:kes-svc.minio.svc.cluster.local, IP:127.0.0.1
subjectKeyIdentifier = hash
EOF

openssl x509 -req -days 365  -in "public.csr" -CA "root-ca.crt" -CAkey "root-ca.key"  -CAcreateserial -out "public.crt" -extfile "minio-crt.conf" -extensions minio_server

cp private.key kes-server.key
cp public.crt kes-server.crt

