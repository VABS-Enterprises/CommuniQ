# Releasing CommuniQ

This is the checklist for shipping the backend and publishing the app to
Google Play and the App Store. Everything the code needs is in place. What is
left are the account-specific IDs, keys and console settings only you can
create. Each one is marked **[YOU]**.

---

## 1. Backend (Render + Firebase)

### 1.1 Deploy the servers

Production (`communiq.onrender.com`) was running an old build: `/levels`,
`/learning`, `/contest` and `/user/visual-reports` returned 404. The most
likely cause is that the Node server refused to start because
`PIPECAT_WEBHOOK_SECRET` wasn't set in production. `render.yaml` now
generates it.

1. **[YOU]** In Render, sync the Blueprint from `render.yaml`, or set these
   variables on the existing services by hand:

   | Service | Variable | Value |
   |---|---|---|
   | AI server | `ENVIRONMENT` | `production` |
   | AI server | `GROQ_API_KEY` | your Groq key |
   | AI server | `AI_SERVER_INTERNAL_KEY` | long random string (same on both) |
   | AI server | `ALLOWED_ORIGINS` | Node URL, e.g. `https://communiq.onrender.com` |
   | Node | `NODE_ENV` | `production` |
   | Node | `FASTAPI_URL` | `https://communiq-ai-server.onrender.com` |
   | Node | `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` | service-account values |
   | Node | `AI_SERVER_INTERNAL_KEY` | same as the AI server |
   | Node | `ADMIN_SECRET` | long random string (≥16 chars) |
   | Node | `PIPECAT_WEBHOOK_SECRET` | long random string (≥16 chars) — **required to boot** |
   | Node | `LIVEKIT_ENABLED` | `false` |

2. **[YOU]** Deploy the branch you are releasing (Render deploys the repo's
   default branch unless the service says otherwise; this work is on
   `version-one`).
3. Check:
   ```bash
   curl https://communiq.onrender.com/health          # {"status":"ok",...}
   curl -i https://communiq.onrender.com/levels       # 401 (route exists), not 404
   ```
4. **Plan:** free instances sleep after ~15 minutes idle. The first request then
   takes up to a minute, and background jobs pause. Use at least **Starter**
   for both services at launch.

### 1.2 Firestore rules and indexes

**[YOU]** From the repo root:
```bash
firebase deploy --only firestore:rules,firestore:indexes --project communiq-f32a0
```
This deploys the tightened rules (clients can't write `users`/`sessions`) and
three new composite indexes:
- weekly leaderboard: `users(weekKey, weeklyXp)`
- contest history: `contestAttempts(userId, submittedAt)`
- contest leaderboard by type: `contestAttempts(contestType, overallScore)`

The server falls back to slower queries until the indexes finish building, so
nothing breaks in the meantime.

### 1.3 One-time data repair

Older onboarding code wrote the self-assessed level (Beginner/Intermediate/
Advanced = 1/2/3) into the XP `level` field. The API now always derives level
from XP, so users see the right value regardless, but repair the stored data
once:
```bash
cd server
npm run users:repair-levels            # dry run — lists what would change
npm run users:repair-levels -- --apply # writes it
```

### 1.4 Live voice (optional, off at launch)

The LiveKit + Pipecat live-voice mode runs Whisper, Kokoro and an LLM locally
in `pipecat-worker/`, which needs a GPU host. It can't run on Render. Launch
uses the HTTP turn mode (`LIVEKIT_ENABLED=false`), which works fully. To enable
live voice later, host the worker and LiveKit yourself (see `livekit/` and the
README), then set `LIVEKIT_ENABLED=true`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`,
`LIVEKIT_API_SECRET` and `PIPECAT_WORKER_URL` on the Node service.

---

## 2. App configuration (both stores)

### 2.1 Public URLs **[YOU]**

Both stores require a public privacy policy URL. The in-app copies (Profile →
Legal) are used when no URL is configured. Host the policy (it can be the same
text as `_kPrivacy` in `client/lib/views/profile_view/screens/profile_view.dart`)
and pass the URLs at build time:

| Define | Purpose |
|---|---|
| `PRIVACY_POLICY_URL` | Privacy policy page (required by both stores) |
| `TERMS_URL` | Terms of service page |
| `SUPPORT_EMAIL` | Support / privacy contact (default `support@communiq.app`; make sure it receives mail) |

See `client/lib/core/constants/app_config.dart`.

### 2.2 Version

Bump `version:` in `client/pubspec.yaml` (`1.0.0+1` → `1.0.1+2` …) for every
upload. The build number (after `+`) must increase on each store upload.

---

## 3. Google Play

### 3.1 Upload keystore **[YOU]**
```bash
keytool -genkey -v -keystore ~/communiq-upload.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias upload
cp client/android/key.properties.example client/android/key.properties
# edit key.properties with the passwords and the absolute path to the .jks
```
`key.properties` and `*.jks` are gitignored. Back the keystore up. Without
`key.properties` the release build is signed with the debug key and Play
rejects it (the Gradle build prints a warning).

### 3.2 Firebase / Google Sign-In fingerprints **[YOU]**
Google Sign-In fails in production unless Firebase knows the signing
certificates:
1. Upload key SHA-1/SHA-256: `keytool -list -v -keystore ~/communiq-upload.jks -alias upload`
2. Play App Signing key: Play Console → *Test and release → App integrity →
   App signing* → copy SHA-1/SHA-256.
3. Add all of them under Firebase Console → Project settings → Android app
   `com.vabs.communiq`, then download the new `google-services.json` into
   `client/android/app/`.

### 3.3 Build
```bash
cd client
flutter build appbundle --release \
  --dart-define=PRIVACY_POLICY_URL=https://… \
  --dart-define=TERMS_URL=https://… \
  --dart-define=SUPPORT_EMAIL=…
# → build/app/outputs/bundle/release/app-release.aab
```
The bundle targets API 36 with R8 enabled. A release build was verified to
install and run on an Android emulator.

### 3.4 Play Console answers
- **App access:** login required. Provide a test account (email + password)
  for reviewers.
- **Data safety:** collected and linked to the user, not shared for
  advertising, encrypted in transit, deletable in-app (Profile → Delete account):
  - Personal info: name, email
  - Audio: voice recordings (processed for transcription, not stored as audio)
  - App activity / user-generated content: transcripts, answers, scores, progress
  - App info: none beyond the above
  - Camera video is processed on device only and is **not** collected
- **Account deletion URL:** Play also asks for a web link where users can
  request deletion. Point it at a page that explains Profile → Delete account
  and gives the support email.
- **Content rating:** complete the questionnaire (no violence or sexual content;
  user-generated text is not shared with other users except display names on
  leaderboards).
- **Target audience:** 13+ (the privacy policy says the app isn't directed at
  children under 13).

---

## 4. App Store

### 4.1 Xcode project **[YOU]**
1. Open `client/ios/Runner.xcworkspace`, select the Runner target →
   *Signing & Capabilities* → choose your **Team**. Bundle ID is
   `com.vabs.communiq`. Change it here and in Firebase if you need a different one.
2. *Sign in with Apple* is already declared in `Runner/Runner.entitlements`.
   Make sure the App ID has the capability enabled in the developer portal.
3. Deployment target is iOS 15.5 (required by ML Kit).

### 4.2 Firebase for iOS **[YOU]**
1. Firebase Console → add an iOS app with bundle ID `com.vabs.communiq` →
   download `GoogleService-Info.plist` → add it to `client/ios/Runner/` in Xcode
   (target: Runner). Firebase won't start on iOS without it.
2. In `client/ios/Runner/Info.plist`, replace
   `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID` with the
   `REVERSED_CLIENT_ID` value from that plist (Google Sign-In crashes
   without it).
3. Firebase Console → Authentication → Sign-in method → enable **Apple**. Add
   the Services ID / key from the Apple developer portal if prompted.

### 4.3 Build
```bash
cd client && cd ios && pod install && cd ..
flutter build ipa --release \
  --dart-define=PRIVACY_POLICY_URL=https://… \
  --dart-define=TERMS_URL=https://… \
  --dart-define=SUPPORT_EMAIL=…
# upload build/ios/ipa/*.ipa with Transporter or Xcode Organizer
```

### 4.4 App Store Connect answers
- **App Privacy:** matches `Runner/PrivacyInfo.xcprivacy`. Collected and linked
  to the user, not used for tracking: Name, Email Address, User ID, Audio Data,
  Other User Content, Gameplay Content. All are for App Functionality; user
  content is also used for Product Personalization.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = NO` is already set
  (HTTPS only).
- **Sign-in:** provide a demo account for App Review.
- **Account deletion:** in-app (Profile → Delete account), as guideline
  5.1.1(v) requires.
- **Sign in with Apple:** offered on iOS alongside Google (guideline 4.8).

---

## 5. Before you submit — manual test pass

On a real device, with a fresh account against the production backend:

- [ ] Sign up (email, Google, and Apple on iOS); onboarding answers appear in Profile
- [ ] New user shows Lv 1 and 0 XP, even after picking "Advanced" in onboarding
- [ ] Finish a roleplay → Home XP/streak and Practise "recent" update without pull-to-refresh
- [ ] Tap a past session → its report opens
- [ ] Finish a contest → hub best score, Home XP and weekly leaderboard update
- [ ] Finish a lesson → XP increases, next lesson unlocks; airplane mode at the end shows Retry
- [ ] Camera analysis: demo run isn't listed in Profile → Camera Reports; a real run appears once
- [ ] Edit display name → leaderboards show the new name
- [ ] Delete account → returns to Welcome; signing in again starts fresh
- [ ] Privacy policy / terms links open
