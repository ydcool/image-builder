# image-builder

Build images using github action

## Images list

### kube-cross

> Origin from https://github.com/kubernetes/release/blob/master/images/build/cross/default/Dockerfile

Changes:
- Add linux/mips64le support.
- optimise run scripts to reduce final image layers' size