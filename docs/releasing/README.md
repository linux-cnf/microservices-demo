# Release process

This repository uses semantic version tags (`vX.Y.Z`), `develop` as the
integration branch, and `main` as production. Release changes should be reviewed
before promotion; do not create or push a tag until the release commit is on
`main` and the release owner explicitly authorizes publication.

## Prepare

1. Fetch branches and tags and verify a clean working tree.
2. Confirm the previous release and ensure the target tag is absent locally and
   on `origin`.
3. Review `git log <previous-tag>..develop` and the corresponding diff.
4. Create a release or feature branch from current `develop`.
5. Update only the artifacts and documentation required by the release.
6. Run the repository's code, Kustomize, Helm, Terraform, YAML, and security
   validation that applies to the changed files.
7. Open a pull request into `develop` and record validation and release notes.

Promote the reviewed release from `develop` to `main` with a separate pull
request. Production Argo CD Applications track `main`; development Applications
track `develop`.

## Tag and publish

After the promotion pull request is merged and the release owner approves:

```bash
git switch main
git pull --ff-only origin main
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

Use the configured release identity for annotated tags. Create the GitHub
release from that exact tag and include a comparison link, verified changes,
validation, and any operational or upgrade notes. Do not upload credentials or
environment-specific configuration as release assets.

## Release artifacts

The scripts in this directory are inherited helpers that build images, regenerate
`release/kubernetes-manifests.yaml`, update Kustomize/Helm artifacts, create a
`release/vX.Y.Z` branch, and push a tag. They perform network writes and currently
assume a direct `main`-based workflow. Inspect their diff and adapt the review
sequence before using them; never run `make-release.sh` merely to prepare release
notes or a documentation-only pull request.

The generated files under `release/` are direct-deployment artifacts. The live
platform normally deploys through the environment-specific Argo CD roots and
Kustomize overlays.

## Release-note template

```markdown
# vX.Y.Z – Title

## Summary

## Changes included

## Operational or upgrade notes

## Validation

**Full comparison:** https://github.com/linux-cnf/microservices-demo/compare/vPREVIOUS...vX.Y.Z
```
