#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "default lisp is sbcl" bash -c "ros config show default.lisp 2>&1 | grep -Fqw 'sbcl'"
check "sbcl version matches" bash -c "ros config show sbcl.version 2>&1 | grep -Eq '[0-9]+\.[0-9]+\.[0-9]+'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
