#!/bin/sh

ADDR='http://localhost'
PORT=8003
TOKEN=1234567890

data="Test at $(date)"
curl -v -d "body=$data" -H "X-AUTH-TOKEN: ${TOKEN}" $ADDR:$PORT/event/test?reenter=1

