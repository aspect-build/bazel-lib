#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail
escape() {
  echo "$1" |
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' |
    awk 1 ORS='&#10;' # preserve newlines
}
fail() {
  cat <<EOF >"${XML_OUTPUT_FILE:-/dev/null}"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="$(escape "{name}")" tests="1" failures="1">
  <testsuite name="$(escape "{name}")" tests="1" failures="1" id="0">
    <testcase name="$(escape "{name}")" assertions="1" status="failed">
      <failure message="$(escape "$1")" type="diff"></failure>
    </testcase>
  </testsuite>
</testsuites>
EOF
  echo >&2 "FAIL: $1"
  exit 1
}

{rlocation_function}

RF1="$(rlocation {file1})"
RF2="$(rlocation {file2})"
DF1=
DF2=
[[ ! -d "$RF1" ]] || DF1=1
[[ ! -d "$RF2" ]] || DF2=1
if [[ "$DF1" ]] && [[ ! "$DF2" ]]; then
  echo >&2 "ERROR: cannot compare a directory \"{file1}\" against a file \"{file2}\""
  exit 1
fi
if [[ ! "$DF1" ]] && [[ "$DF2" ]]; then
  echo >&2 "ERROR: cannot compare a file \"{file1}\" against a directory \"{file2}\""
  exit 1
fi
if [[ "$DF1" ]] || [[ "$DF2" ]]; then
  if ! diff -r "$RF1" "$RF2"; then
    fail "directories \"{file1}\" and \"{file2}\" differ. {fail_msg}"
  fi
else
  if ! diff "$RF1" "$RF2"; then
    fail "files \"{file1}\" and \"{file2}\" differ. {fail_msg}"
  fi
fi
