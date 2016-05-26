#!/bin/bash
# Generates a StartSSL cert, you need to
# verify your domain before using this script.
# Also you need to create a StartAPI certificate and API token.
# docs: https://startssl.com/StartAPI/Docs

# requires coreutils for base64 and node json tool
# sudo apt-get -y install coreutils
# sudo npm install -g json

source startssl.conf

DOMAIN="$1"

[ ! -f  "$CERT" -o -z "$CERT" ] && { echo "PEM encoded StartAPI authentication certificate is required."; exit -1; }
[ -z "$API_TOKEN" ] && { echo "StartAPI Token is required. You can set it in apitoken file."; exit -1; }
[ -z "$DOMAIN" ] && { echo "Domain needs to be specified eg. server1.example.com."; exit -1; }

rm -rf $DOMAIN
mkdir $DOMAIN
# Generate key and CSR
openssl req -nodes -newkey rsa:2048 -subj "/CN=$DOMAIN" -keyout $DOMAIN/$DOMAIN.key -out $DOMAIN/$DOMAIN.csr 2>/dev/null

CSR=$(sed ':a;N;$!ba;s/\n/\\n/g' $DOMAIN/$DOMAIN.csr)
RES=$(curl --silent -X POST --data-urlencode "RequestData={\"tokenID\":\"$API_TOKEN\",\"actionType\":\"ApplyCertificate\",\"certType\":\"DVSSL\",\"domains\":\"$DOMAIN\",\"CSR\":\"$CSR\"}" --cert $CERT $API_ENDPOINT)

STATUS=$(echo $RES | json status)
MSG=$(echo $RES | json shortMsg)
[ $STATUS -ne 1 ] && { echo "Order failed, because $MSG"; exit -1; }

STATUS=$(echo $RES | json data.orderStatus)
MSG=(NC Pending Issued Rejected)
[ $STATUS -ne 2 ] && { echo "Order ${MSG[$STATUS]}, check your account."; exit -1; }

CERT_B64=$(echo $RES | json data.certificate)
INTER_CERT_B64=$(echo $RES | json data.intermediateCertificate)

echo $CERT_B64 | base64 -d > $DOMAIN/$DOMAIN.crt
echo $CERT_B64 | base64 -d  > $DOMAIN/${DOMAIN}_combined.crt
echo >> $DOMAIN/${DOMAIN}_combined.crt
echo $INTER_CERT_B64 | base64 -d >> $DOMAIN/${DOMAIN}_combined.crt
echo $INTER_CERT_B64 | base64 -d > $DOMAIN/startssl_cert_chain.crt
echo "Done, certificate are in $(readlink -f $DOMAIN)" 
