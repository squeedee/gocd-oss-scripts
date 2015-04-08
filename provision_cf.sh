#!/usr/bin/env bash

set -xe

STEMCELL_SOURCE=http://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/warden
STEMCELL_FILE=latest-bosh-stemcell-warden.tgz
WORKSPACE_DIR="$(cd $(dirname ${BASH_SOURCE[0]})/../ && pwd)"
BOSH_LITE_DIR="${WORKSPACE_DIR}/bosh-lite"
CF_DIR="${WORKSPACE_DIR}/cf-release"
BOSH_LITE_IP=`cat $BOSH_LITE_DIR/api-address`
chruby 1.9.3
echo $BOSH_LITE_IP

export LATEST_CF_FINAL_RELEASE=`ls ${CF_DIR}/releases/cf-*.yml | sed -n 's/.*releases\/cf-\(.*\)\.yml$/\1/p' | sort -n | tail -1`
echo "Using latest CF final release: $LATEST_CF_FINAL_RELEASE"

main() {
  fetch_stemcell
  upload_stemcell
  build_manifest
  deploy_release
}

fetch_stemcell() {
  if [[ ! -e $STEMCELL_FILE ]]
  then
    curl --progress-bar "${STEMCELL_SOURCE}/${STEMCELL_FILE}" > "$STEMCELL_FILE"
  fi
}

upload_stemcell() {
  bosh -n target $BOSH_LITE_IP
  bosh login admin admin
  bosh upload stemcell --skip-if-exists $STEMCELL_FILE
}

build_manifest() {
  env
  cd $CF_DIR
  git checkout v$LATEST_CF_FINAL_RELEASE
  ./update

  export CF_RELEASE_DIR=$CF_DIR
  mkdir -p bosh-lite/manifests
  SYSTEM_DOMAIN_STUB=bosh-lite/manifests/system_domain_stub.yml
  cat <<SYSTEM_DOMAIN_STUB > $SYSTEM_DOMAIN_STUB
properties:
  domain: ${BOSH_LITE_IP}.xip.io
  system_domain: ${BOSH_LITE_IP}.xip.io
  app_domains:
  - ${BOSH_LITE_IP}.xip.io
SYSTEM_DOMAIN_STUB

  DEPLOYMENT_NAME=${CF_DEPLOYMENT_NAME:-cf-warden}
  DEPLOYMENT_NAME_STUB=bosh-lite/manifests/deployment_name_stub.yml
  cat <<DEPLOYMENT_NAME_STUB > $DEPLOYMENT_NAME_STUB
meta:
  environment: $DEPLOYMENT_NAME
name: $DEPLOYMENT_NAME
DEPLOYMENT_NAME_STUB

  bosh-lite/make_manifest $SYSTEM_DOMAIN_STUB $DEPLOYMENT_NAME_STUB
  cat bosh-lite/manifests/cf-manifest.yml
}

deploy_release() {
  MOST_RECENT_CF_RELEASE=$(find ${CF_DIR}/releases -regextype posix-basic -regex ".*cf-[0-9]*.yml" | sort | tail -n 1)
  cd $CF_DIR
  bosh upload release --skip-if-exists releases/cf-${LATEST_CF_FINAL_RELEASE}.yml
  bosh -n deploy
}

main
