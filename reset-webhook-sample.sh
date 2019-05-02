#!/bin/sh

#export ALL_PROXY=http://name:password@proxy.address:3128

TOKEN=YOUR_TOKEN_HERE

curl -F "url=" https://api.telegram.org/bot$TOKEN/setWebhook

