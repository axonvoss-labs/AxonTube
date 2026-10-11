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

Public application archives use the prepared release-helper profile documented
in [source and dependency access](SOURCE-ACCESS.md). The older standalone helper
preparation remains available for local review; the release archive script
rejects that profile. Dependency downloads require an explicit preparation step.

```sh
python3 scripts/prepare-release-helper.py --download \
  --cache dist/helper-downloads --output dist/release-helper-arm64
bash scripts/package.sh --helper-dir dist/release-helper-arm64 \
  --output-dir dist/app-0.5.3
bash scripts/package-release.sh --app dist/app-0.5.3/AxonTube.app \
  --helper-dir dist/release-helper-arm64 --output-dir dist/release-0.5.3
```

Choose fresh output directories for later builds. The scripts validate the
helper inventory, create the original icon, strip private build paths, sign
the application ad hoc, and produce these release assets:

- `AxonTube-0.5.3-macos-arm64.dmg`
- `AxonTube-0.5.3-macos-arm64.zip`
- `AxonTube-0.5.3-dependency-materials.tar.gz`
- `SHA256SUMS.txt`

Before publication, verify the extracted ZIP and mounted DMG, launch the
extracted app, run its bundled helper from a path containing spaces, and check
that its resources and signatures remain valid afterward. Inspect archives for
private paths, user media, credentials, build caches, and identifying metadata.
Keep required dependency notices. Record live YouTube results separately from
offline fixture tests.

Create the release tag from the reviewed commit in the dedicated publication
checkout and push only that tag to both remotes. Create a draft GitHub Release
with the four verified assets, use a prerelease label for this preview, and
expand relative links in the bilingual release notes before publishing them.
Do not reuse an existing tag or replace published assets during a routine
update. After publication, download the public assets again, verify their
checksums, and compare both remote tag targets with the publication commit.

The preview is not Developer ID signed or notarized. A successful build does
not establish compatibility with untested Macs or resolve restrictions imposed
by online services. Keep these limits visible in the release notes and
[installation instructions](INSTALL.md).
