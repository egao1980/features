#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "execute command" bash -c "ros 2>&1 | grep -Fq 'Common Lisp environment setup Utility.'"
check "execute command" bash -c "ros -e '(format t (ql-dist:version (ql-dist:find-dist \"quicklisp\")))' 2>&1 | grep -Fqw '2023-02-15'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
