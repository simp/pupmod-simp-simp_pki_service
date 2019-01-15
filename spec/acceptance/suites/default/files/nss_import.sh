#!/bin/bash
ca=$1

echo "Importing certs from $HOME/.dogtag/$ca into NSS database for $ca"

cd $HOME/.dogtag
mkdir crt_tmp_$ca
cd crt_tmp_$ca

# Obtain the PKCS12 certificate chain from the server

pki-server subsystem-cert-export ca signing -i $ca \
--no-key \
--pkcs12-file $ca-certs.p12 \
--pkcs12-password-file $HOME/.dogtag/$ca/ca/password.conf

# Generate a PEM file containing the CA certificate chain from the PKCS12 file

openssl pkcs12 -in $ca-certs.p12 \
-passin file:$HOME/.dogtag/$ca/ca/password.conf \
-out $ca-ca-chain.pem

# Split the PEM file out into separate PEM files for each CA
# This is done to get them into into your NSS database
#
# You may also want to provide these to your clients for download but the
# single file version is generally preferred

mkdir ca_certs
awk '/friendlyName:/{$1="";sub($1 OFS, "");n=$0} \
/^-----BEGIN.*CERTIFICATE/,/^-----END.*CERTIFICATE/{print >"ca_certs/"n".pem"}' \
< $ca-ca-chain.pem

# Finally, import the CA certificates into the associated trust chain NSS
# database

cd ca_certs
pki_cmd_base="pki -d $HOME/.dogtag/$ca/ca/alias -C $HOME/.dogtag/$ca/ca/password.conf"
for x in *.pem; do
  ${pki_cmd_base} client-cert-import "`basename "$x" .pem`" --ca-cert "$x"
done

