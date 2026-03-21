#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "lem reports a version" bash -c "lem --version 2>&1 | grep -Eq '[0-9]+\.[0-9]+'"

# Report results
reportResults
