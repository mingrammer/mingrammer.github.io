# mingrammer.github.io
https://mingrammer.com

## Setup

```bash
git clone git@github.com:mingrammer/mingrammer.github.io

# Add submodule for master branch (for publish)
git submodule add -b master git@github.com:mingramemr/mingrammer.github.io.git public

# Checkout to hugo root branch
git checkout hugo
```

## Deployment

```bash
./deploy "<commit-message>"
```
