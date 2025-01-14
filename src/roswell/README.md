
# Roswell (roswell)

Installs the provided version of Roswell, as well as a chosen Common Lisp implementation, and other common CL utilities.

## Example Usage

```json
"features": {
    "ghcr.io/egao1980/features/roswell:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select a Roswell version to install. | string | latest |
| quicklispVersion | Select a Quicklisp dist version to use. | string | latest |
| installUltralisp | Flag indicating whether or not to install the Ultralisp distribution. Default is 'false'. | boolean | false |
| installTools | Flag indicating whether or not to install the tools specified via the 'toolsToInstall' option. Default is 'false'. | boolean | true |
| toolsToInstall | Comma-separated list of tools to install when 'installTools' is true. Defaults to a set of common tools like qlot. | string | qlot |
| installLisp | Common Lisp implementation to install in Roswell. | string | none |
| useLisp | Common Lisp implementation to use in Roswell. | string | sbcl-bin |
| installPath | The path where roswell will be installed. | string | /usr/local/roswell |
| httpProxy | Connect to GPG keyservers using a proxy for fetching source code signatures by configuring this option | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/egao1980/features/blob/main/src/roswell/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
