#!/bin/sh
set -e

cd frontend
npm install
npm run build

cd ..
echo "Backend"

mkdir -p web/html
rm -fr web/html/*
cp -R frontend/dist/. web/html/

sed -i 's#module github.com/chihiroecho-eng/s-ui#module github.com/admin8800/s-ui#' go.mod
sed -i 's#github.com/chihiroecho-eng/s-ui#github.com/admin8800/s-ui#g' main.go

BUILD_TAGS="with_quic,with_grpc,with_utls,with_acme,with_gvisor,with_naive_outbound,with_musl,badlinkname,tfogo_checklinkname0,with_tailscale"
go build -ldflags '-w -s -checklinkname=0 -extldflags "-Wl,-no_warn_duplicate_libraries"' -tags "$BUILD_TAGS" -o sui main.go
