#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "execute command" bash -c "lem --version 2>&1 | grep -Fq '2.1.0-e366bda7'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
