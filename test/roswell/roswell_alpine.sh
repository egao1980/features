#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "ros is on PATH" bash -c "ros 2>&1 | grep -Fq 'Common Lisp environment setup Utility.'"
check "qlot is installed" bash -c "qlot 2>&1 | grep -Fq 'Initialize a project to start using Qlot.'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
