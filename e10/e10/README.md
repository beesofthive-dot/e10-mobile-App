# e10 School Systems

Flutter parent / teacher / admin mobile app with a Laravel API in the **`backend`** folder.

## API

The application uses the production Laravel API configured in `.env`:
`https://e10.beesofthive.pro/api`

## Run the mobile app in Chrome

```bash
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8081
```

Or double-click `run_chrome.cmd`. Open **http://127.0.0.1:8081**.

The app probes the configured API automatically. Sign-in requires an active account
on the school API: parents use their registered phone number and one-time code,
while teachers and administrators use their staff email and password or staff
one-time code. The app does not provide offline demo accounts. Before submitting
for Google Play review, provide a working reviewer account and any required
one-time-code instructions in Play Console's **Sign in details** section.

## Google Play photo and video permissions

Daily-report photos are selected with Android's system Photo Picker. The app
does not request broad photo or video library access. The Android release
manifest removes `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, and
`READ_MEDIA_VISUAL_USER_SELECTED`, and the release manifest build task fails if
any of them are reintroduced.

Before uploading a release, verify the generated app bundle's merged manifest
contains none of those permissions. Since the app uses the system picker
instead, it should not need a Play Console declaration for broad photo/video
access. Keep the Play Console Data safety answers accurate for the app's actual
photo upload behavior. Increment the build number in `pubspec.yaml` for each
Play upload, then build the release bundle with:

```bash
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab`. In Play Console,
remove or replace non-compliant releases from every active track (including
testing tracks); uploading this bundle does not update or remove older releases
automatically.
