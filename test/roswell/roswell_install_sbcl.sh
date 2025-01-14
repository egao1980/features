#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "execute command" bash -c "ros config show default.lisp 2>&1 | grep -w 'sbcl-bin'"
check "execute command" bash -c "ros config show sbcl.version 2>&1 | grep -w '2.5.0'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
