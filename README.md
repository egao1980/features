# Common Lisp devcontainer features

This repository contains a _collection_ features for developing Common Lisp software. Each sub-section below shows a sample `devcontainer.json` alongside example usage of the Feature.

## `roswell`

This feature will install and configure `roswell` tool with the requested Common Lisp implementation and extra tools. A specific version of Quicklisp distribution could be specified. Ultralisp distribution can be added as well.

### Basic setup with `sbcl-bin` as default CL implementation:

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/egao1980/features/roswell:1": {
            "version": "latest",
        }
    }
}
```

```bash
$ ros 
Common Lisp environment setup Utility.

Usage:

   ros [options] Command [arguments...]
or
   ros [options] [[--] script-path arguments...]

commands:
   run       Run repl
   install   Install a given implementation or a system for roswell environment
...
```

### Build SBCL and use `qlot` with Ultralisp

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/egao1980/features/roswell:1": {
            "version": "latest",
            "installLisp": "sbcl/2.5.0",
            "useLisp": "sbcl/2.5.0",
            "installTools": true,
            "installUltralisp": true
        }
    }
}
```

## `lem`

This feature provides a Lem project's `lem` editor. The feature depends on `roswell` with `qlot` installed and will automatically install the corresponding feature if not already present in the Devcontainer definition.

### Basic setup with latest Git version of Lem

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:alpine",
    "features": {
        "ghcr.io/egao1980/features/lem:1": {
            "version": "latest"
        }
    }
}
```

### Selecting a specific version of Lem 

This uses `version` option to select git tag / branch name to install.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:alpine",
    "features": {
        "ghcr.io/egao1980/features/lem:1": {
            "version": "v2.2.0"
        }
    }
}
```
