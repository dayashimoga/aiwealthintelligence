# GitHub Actions Capabilities & Validation

We verified the configurations in [.github/workflows/deploy.yml](file:///h:/investment/.github/workflows/deploy.yml) and [.github/workflows/ci.yml](file:///h:/investment/.github/workflows/ci.yml) to ensure their capability to generate app artifacts and deploy the web app to Cloudflare Pages.

---

## 1. App Artifacts Generation

GitHub Actions runner environments natively support Java, Android, and iOS SDK compilation:

### A. Android builds (`ubuntu-latest`)
* **Java Setup**: Using `actions/setup-java@v4` with OpenJDK 17 ensures standard Android compatibility.
* **Flutter Setup**: Using `subosito/flutter-action@v2` installs a cached version of Flutter.
* **Compilation**: `flutter build apk` and `flutter build appbundle` output files to `apps/web/build/app/outputs/`.
* **Artifact Upload**: The generated `.apk` and `.aab` packages are successfully saved as downloadable ZIP packages under the workflow run dashboard using `actions/upload-artifact@v4`.

### B. iOS builds (`macos-latest`)
* **Runner Platform**: iOS builds require Xcode, which is natively pre-installed on the `macos-latest` GitHub-hosted runners.
* **Compilation**: The script runs `flutter build ios --release --no-codesign`. The `--no-codesign` flag is crucial for CI setups to build the archive/app file without needing access to private distribution certificate stores.
* **Artifact Upload**: Uploads the complete raw `.app` structure from `apps/web/build/ios/iphoneos` for validation and deployment setups.

---

## 2. Cloudflare Pages Website Deployment

Cloudflare Pages can host static assets directly. Since Flutter builds compile down into single-page HTML/JavaScript structures, it works natively on Cloudflare Pages:

### A. Deployment Execution
* The build step executes `flutter build web --release --web-renderer canvaskit`.
* The upload uses the standard `cloudflare/wrangler-action@v3`.
* It deploys directly to the target environment (`pages deploy apps/web/build/web`) with:
  * `apiToken`: `${{ secrets.CLOUDFLARE_API_TOKEN }}`
  * `accountId`: `${{ secrets.CLOUDFLARE_ACCOUNT_ID }}`
  * `project-name`: `wealthai`

### B. Pull Request (PR) Previews
* Preview URLs are automatically generated on every PR because wrangler uses `--branch=${{ github.head_ref || github.ref_name }}`. Cloudflare creates branch-isolated preview endpoints (e.g., `https://<pr-branch>.wealthai.pages.dev`) for live team validation before merging.

---

## 3. GitHub Releases Automation

* The `release` job runs when a commit matching `release:` is merged.
* It automatically pulls down the compiled artifacts (APK) and publishes them directly to the GitHub Releases page with automated changelogs.
