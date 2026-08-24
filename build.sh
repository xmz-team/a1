#!/bin/bash

script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"

"${script_path}/generate-version.sh"

${script_path}/build.a1
${script_path}/build.a1ctl
${script_path}/build.a1mod
${script_path}/build.a1pm
