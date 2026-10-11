# GitHub Packages / GitHub 软件包

AxonTube's [GitHub package](https://github.com/users/axonvoss-labs/packages/container/package/axontube)
stores the same four verified files as its
[v0.5.3 release](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3):
the Apple silicon macOS DMG, ZIP, dependency-materials archive, and
`SHA256SUMS.txt`. The reference is `ghcr.io/axonvoss-labs/axontube:0.5.3`.
This is a **macOS download artifact, not a runnable Linux container**.
GitHub lists this OCI artifact under Packages; do not use `docker run` to
install or launch the macOS app. The release remains the direct download option.

With [ORAS](https://oras.land/docs/installation/) installed, download into a new
directory and verify the three payload files on macOS:

```sh
oras pull ghcr.io/axonvoss-labs/axontube:0.5.3 --output AxonTube-0.5.3-package
cd AxonTube-0.5.3-package
shasum -a 256 -c SHA256SUMS.txt
```

Open `AxonTube-0.5.3-macos-arm64.dmg` and copy AxonTube to Applications, or
extract the ZIP. ORAS is only an alternative way to download; the app does not
need ORAS or Docker. Public GHCR packages allow anonymous downloads. To pin
the exact OCI artifact, replace `:0.5.3` with the `@sha256:…` digest displayed
on the package version page or in the publication workflow summary.

The [publication workflow](../.github/workflows/publish-package.yml) runs when
a release is published, or through **Actions → Publish macOS download package
→ Run workflow** with a `vMAJOR.MINOR.PATCH` release tag. It uses the workflow's
`GITHUB_TOKEN` with `contents: read` and `packages: write`; no additional token
or secret is required. ORAS 1.3.4 is downloaded from its official release and
checked against a pinned SHA-256. No Docker daemon or repository checkout is
needed. The workflow rejects drafts, unexpected assets, checksum mismatches,
and existing package version tags. It publishes the release's original files
and verifies an immediate pull by manifest digest. An existing version must
not be replaced; publish a new release version for changed files.

The manifest's `org.opencontainers.image.source` points to
<https://github.com/axonvoss-labs/AxonTube>, and publication through this
repository's workflow associates the package with the repository. For the
first publication, open the package page, choose **Package settings → Change
visibility → Public**, and confirm the package name. GitHub creates packages
as private even when their linked source repository is public. Making a
package public cannot be reversed. Confirm the source repository connection
and the public repository's Packages sidebar, then test the pull while signed
out. If a previously created package is not linked, connect AxonTube from the
package settings and grant this repository Actions access before publishing.
See GitHub's [registry authentication](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
and [visibility guidance](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility).

---

AxonTube 的 [GitHub 软件包](https://github.com/users/axonvoss-labs/packages/container/package/axontube)
保存与 [v0.5.3 Release](https://github.com/axonvoss-labs/AxonTube/releases/tag/v0.5.3)
一致的四个已校验文件：Apple silicon macOS 的 DMG、ZIP、依赖源码与许可证材料包，以及
`SHA256SUMS.txt`。软件包地址为 `ghcr.io/axonvoss-labs/axontube:0.5.3`。
这是 **macOS 安装文件的 OCI 分发包，不是可运行的 Linux 容器**。
请勿用 `docker run` 安装或启动此应用；也可以直接从 Release 下载安装包。

安装 [ORAS](https://oras.land/docs/installation/) 后，可运行上方命令下载全部文件并校验。
打开 `AxonTube-0.5.3-macos-arm64.dmg`，将 AxonTube 复制到“应用程序”，或解压 ZIP。
应用本身不需要 ORAS 或 Docker。公开的 GHCR 软件包无需登录即可下载；需要固定内容时，
使用软件包版本页面或发布工作流摘要中的 `@sha256:…` 替代 `:0.5.3`。

发布者可发布新的 GitHub Release，或在 **Actions → Publish macOS download package
→ Run workflow** 中填写 `v主版本.次版本.修订版本`。工作流使用自带的 `GITHUB_TOKEN`，
无需另建 PAT 或 secret；它检查真实 Release 的四个文件与校验值，拒绝覆盖已有版本，
上传后按 digest 重新下载并校验。安装包有变化时，应发布新版本。

首次发布后，软件包默认仍为 private。请在软件包页面进入 **Package settings → Change
visibility → Public**，输入包名确认；变为 public 后无法改回 private。
源码仓库公开不会自动让软件包公开。确认软件包已关联 AxonTube、仓库右侧 Packages 中
可见，再在未登录状态验证下载。发布内容保留各依赖原有许可证，材料包与安装包同时提供。
