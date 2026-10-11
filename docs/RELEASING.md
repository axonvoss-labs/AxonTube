# Source publication and synchronization

AxonTube uses the `axontube` publication branch. Its GitHub repository and the
configured local Git mirror receive the same commit. The project source is a
developer preview; a source update does not imply a signed application release.
Only AxonTube is authorized for public GitHub. Legacy products, branches, and
their history remain local and must never be included in a public push.

## Before publishing

1. Confirm that the change belongs to AxonTube. Keep legacy product branches
   and their history separate; do not push all branches or mirror an unrelated
   Git database.
2. Review the source diff and run the checks appropriate to the change. For the
   first source publication or application changes, build in release mode and
   run the core, model, caption, and video-save checks listed in the README.
   Check Markdown links, assets, and the rendered result for documentation
   changes. Report online-service verification separately from offline tests.
3. Inspect tracked files, media metadata, and outgoing commit identities for
   personal information, private addresses, credentials, or machine paths.
   Use the project identity and an anonymous address in publication commits.
   Retain all required third-party licenses and copyright notices.
4. Export the reviewed tracked tree into the dedicated publication checkout.
   A first publication starts a clean history; subsequent updates extend that
   history. Preserve development history privately. Do not import development
   branches merely to transfer files.

## Synchronize

The publication checkout defines `github` and `local` remotes. Confirm their
destinations locally before pushing; private mirror URLs do not belong in
public project files. Never force-push during a routine update.

```sh
git push github axontube:axontube
git push local axontube:axontube
git rev-parse axontube
git ls-remote github refs/heads/axontube
git ls-remote local refs/heads/axontube
```

Both returned branch tips must equal the local publication commit. On the
first publication, also clone the GitHub branch into a separate directory and
compare the tracked tree. Check that the GitHub README, images, language links,
and default branch refer to AxonTube. If one push fails, report the partial
state and finish synchronizing that destination before declaring completion.

## Required update report

- Product and publication branch.
- GitHub: updated, already current, or failed.
- Local Git mirror: updated, already current, or failed.
- Publication commit and remote-tip comparison result.
- Checks actually performed and material failures or unverified behavior.

## Application archives

Public application archives require their own distribution review. A successful
source publication does not resolve signing, notarization, wider Mac testing,
or the bundled helper's corresponding-source requirements. See
[source and dependency access](SOURCE-ACCESS.md).
