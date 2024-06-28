# kubectl-cpfs

A kubectl plugin for Cloud Pak Foundational Services (CPFS) that provides a set of commands to help you manage your CPFS instance.

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## How to use

### Dependencies
- `oc` CLI
- `yq` CLI

### Installation
- Clone this repository and navigate to the cloned folder
    ```bash
    git clone git@github.com:IBM/ibm-common-service-operator.git
    cd ibm-common-service-operator
    ```

- Check out to `scripts-adopter` branch
    ```bash
    git checkout scripts-adopter
    ```

- Add current folder PATH to your environment variable `PATH`
    ```bash
    export PATH=$PATH:$(pwd)
    ```

- Verify the plugin
    ```bash
    oc plugin list
    ```

### Commands
Run `oc cpfs` to see more details