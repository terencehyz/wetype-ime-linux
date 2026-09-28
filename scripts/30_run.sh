#!/usr/bin/env bash
cd "$(dirname "$0")/.."
export LD_LIBRARY_PATH="$PWD/runtime"
exec ./harness/probe "$@"
