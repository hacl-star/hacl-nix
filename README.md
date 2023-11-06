# HACL* lock files

This repository holds nightly lock files for the
[HACL\*](https://github.com/hacl-star/hacl-star) flake. CI ensures that a new
lock file is committed only if HACL\* builds. Thus build should succeed on every
commit of this repository, indefinitely. The purpose of this repository is to
help bisect issues in HACL\* over long periods of time.

At some point it held Nix expressions to build HACL\* and its dependencies,
those were moved to their respective repositories. It also held some helper
functions for the Hydra-based CI, those were moved to
[hacl-ci](https://github.com/hacl-bot/hacl-ci).
