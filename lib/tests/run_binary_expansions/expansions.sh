#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

mkdir -p $(dirname $1)
outfile=$1
rm -f $outfile
for each in $@; do
  sanitized=${each/darwin_arm64/PLATFORM}
  sanitized=${sanitized/k8/PLATFORM}
  sanitized=${sanitized/_arm64/}
  echo $sanitized >>$outfile
done
