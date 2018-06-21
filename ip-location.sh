#!/usr/bin/bash

# Expect JSON file with line: "country": "US"
# Country can be 2 or 3 chars

TOKEN=207ab2944c8a32
curl -s ipinfo.io?token=$TOKEN | awk '/country/ { \
  if (length($2) == 5 ) { LEN=2 } \
  else { LEN=3 }; \
  print substr($2,2,LEN) \
}'
