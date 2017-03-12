#!/usr/bin/env bash

# Set shell options.
set -eux

readonly GITHUB_URL='https://api.github.com'
readonly GITHUB_OWNER='llamerada-jp'
readonly GITHUB_REPO='libwebrtc'

readonly GITHUB_PATH="${GITHUB_URL}/repos/${GITHUB_OWNER}/${GITHUB_REPO}"

. common.sh

get_platform_info
check_platform
get_chrome_version

cd `dirname $0` || exit 1
SCRIPT_PATH=${PWD}
DEST_PATH=${SCRIPT_PATH}/opt/${ID}-${VERSION_ID}-${ARCH}

# Archive lib and include files.
cd ${DEST_PATH}
case ${ID} in
    'macosx')
	FILE=${PWD}/libwebrtc-${ID}-${CHROME_VERSION}.zip
	;;
    'ubuntu')
	FILE=${PWD}/libwebrtc-${ID}-${VERSION_ID}-${ARCH}-${CHROME_VERSION}.tar.gz
	tar -czf ${FILE} lib include
	;;
    *)
	exit 1
	;;
esac

upload_url=`curl ${GITHUB_PATH}/releases | jq -r "map(select(.body == \"${CHROME_VERSION}\")) | .[].upload_url"`


if [ "${upload_url}" = '' ]; then
    release_json=`cat << EOS
{
  "tag_name": "v${CHROME_VERSION}",
  "target_commitish": "master",
  "name": "v${CHROME_VERSION}",
  "body": "${CHROME_VERSION}",
  "draft": false,
  "prerelease": false
}
EOS
`
    upload_url = `curl -v -u "${GITHUB_OWNER}:${GITHUB_PASSWORD}" -H 'Content-type: application/json' -d "${release_json}" "${GITHUB_PATH}/releases" | jq -r ".upload_url"`
fi

cd ${DEST_PATH}
upload_url=${upload_url%assets*}
upload_url="${upload_url}assets?name=$(basename $FILE)"
curl -v -u "${GITHUB_OWNER}:${GITHUB_PASSWORD}" -H "Content-Type: $(file -b --mime-type $FILE)" --data-binary @${FILE} ${upload_url}
