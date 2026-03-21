#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "ros is on PATH" bash -c "ros 2>&1 | grep -Fq 'Common Lisp environment setup Utility.'"
check "lem is on PATH" bash -c "lem --version 2>&1"

# Report results
reportResults
