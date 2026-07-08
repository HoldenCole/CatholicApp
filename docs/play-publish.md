# Publishing Introibo to Google Play

Step-by-step for taking the current `android/` build to the Play Store.
Covers all three of the publishing issues at the start of this branch:

1. **The Play Console is sitting on the old closed-testing AAB** — needs a
   fresh AAB built from the *current* repo before production is requested.
2. **Launcher icon was a flat red square** — fixed; the AAB you build now
   will ship the real monstrance.
3. **Marketing assets stale** — feature graphic regenerated; screenshots
   need fresh Android captures (see `docs/play-screenshots.md`).

---

## 0. One-time setup

- **JDK 17** installed (Android Studio bundles a compatible JBR).
- **Android Studio Hedgehog** or newer, with SDK **API 35** installed.
- The **upload keystore** used to sign the original closed-testing AAB.
  Without it Play will reject the new AAB (signing key mismatch). If you
  generated it through Play App Signing's "let Google manage your upload
  key", you also have an upload key on your machine — find it before
  proceeding. Don't lose this; it's permanent.

If you're on a new machine and can't find the keystore, you can request a
new upload key from the Play Console (Setup → App integrity → App signing
→ "Request upload key reset"). It takes ~48 hours to approve.

---

## 1. Confirm the version

`android/app/build.gradle.kts` is now at:

```kotlin
versionCode = 14         // strictly higher than any build already uploaded
versionName = "1.2.2"    // user-visible content version (Apple's train for the same content is 1.5.6)
```

Play rejects any AAB whose `versionCode` is ≤ the highest already on the
account, including in closed-testing. If you've uploaded other test
builds since this branch was opened, bump `versionCode` again before
running the build.

---

## 2. Build a signed release AAB

From `android/`:

```sh
./gradlew clean bundleRelease
```

The signed AAB lands at:

```
android/app/build/outputs/bundle/release/app-release.aab
```

Verify the build is the new icon set:

```sh
unzip -l app/build/outputs/bundle/release/app-release.aab \
  | grep -E 'mipmap.*ic_launcher' | head -20
```

You should see `mipmap-anydpi-v26/ic_launcher.xml`,
`ic_launcher_foreground.png` for every density, and the regenerated
legacy `ic_launcher.png` files. If the adaptive XMLs are missing, the
build is stale — clean and rebuild.

(In Android Studio: **Build → Generate Signed Bundle → Android App
Bundle**, pick the keystore, choose "release" → produces the same AAB.)

---

## 3. Upload to Play Console

Two paths depending on how cautious you want to be:

### A. Promote through closed testing (recommended)

1. Open **Play Console → Introibo → Testing → Closed testing → [your
   track]**.
2. **Create new release**.
3. Drop the new AAB. Play will warn that you're replacing the existing
   one; that's fine — the old build is what was wrong.
4. Set release notes (something like
   *"Fixes launcher icon; minor bug fixes for 1.2.2."*).
5. **Save → Review → Start rollout to closed testing**.
6. Wait until the new build is the "Latest release" on the track (a
   few minutes to a couple of hours for review).
7. Install on a tester device and confirm:
   - Launcher icon shows the **monstrance**, not a red square.
   - App opens, scrolls, prays correctly.

8. When happy, in the closed-testing track click **Promote release →
   Production**, then complete the production rollout flow (countries,
   percentage, etc).

### B. Push straight to production (faster, riskier)

1. **Play Console → Production → Create new release** and drop the AAB
   there directly.
2. Same release notes / review flow.
3. Roll out at 20–50% and watch for crash reports for a couple of days
   before going to 100%.

Path A is safer because the icon and any regression would surface to a
tester before any real user gets it. With ~5,000 iOS downloads of
goodwill, B → finding a regression in prod would be costly.

---

## 4. Update the store listing (one time)

In **Play Console → Grow → Store presence → Main store listing**:

| Field             | Source in repo                                      |
|-------------------|-----------------------------------------------------|
| App icon (512²)   | `google-play-screenshots/app-icon-512.png`          |
| Feature graphic   | `google-play-screenshots/feature-graphic-1024x500.png` *(regenerated this branch)* |
| Phone screenshots | `google-play-screenshots/phone-NN.png` *(genuine Android, captions corrected for 1.2.2 — ready to upload)* |
| 7" tablet         | `google-play-screenshots/tablet-7in-NN.png`         |
| 10" tablet        | `google-play-screenshots/tablet-10in-NN.png`        |
| Short description | `google-play-screenshots/STORE_LISTING.md`          |
| Full description  | `google-play-screenshots/STORE_LISTING.md`          |

The STORE_LISTING.md numbers are verified against shipped data for 1.2.2
(574 propers, 67 prayers, 97 flashcards, 41 articles, 14 stations,
8 hours, 7 saints, 16 prefaces). If you update the listing copy on the
console without changing the file, copy the result back into
STORE_LISTING.md so the repo stays the source of truth.

---

## 5. Common gotchas

- **"Version code 12 has already been used"** — bump `versionCode` again
  and rebuild. Track versions are immutable once consumed.
- **"Upload key fingerprint does not match"** — you signed with the wrong
  keystore. Either find the right one or request an upload key reset (~48h).
- **"Your app does not target the required Android version"** — already
  on `targetSdk = 35`, well above Play's current floor. No action.
- **"This release contains debugging symbols"** — set `isMinifyEnabled =
  true` in build.gradle release block if Play complains; right now it's
  off and Play allows that.
- **No internet permission needed.** The app is fully offline. The
  manifest currently requests `POST_NOTIFICATIONS`,
  `SCHEDULE_EXACT_ALARM`, and `RECEIVE_BOOT_COMPLETED` — Play's data
  safety form should list "No data collected / shared" and the
  permissions reflect only the local reminder scheduler.

---

## 6. After production rollout

- Tag the commit: `git tag android-1.2.2 && git push --tags`.
- Update `README.md` if it claims an Android version different from the
  shipped one (it currently doesn't pin an Android version, so no change).
- Bump `versionCode` to 15 in `build.gradle.kts` on `main` so the next
  upload is always higher.
