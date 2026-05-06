# Veloce Express Android Release Checklist

Before sharing a public APK:

- Test client signup, driver signup, email verification, and admin approval.
- Test order creation, bidding, bid acceptance, active trip return, call button, delivery confirmation, and driver rating.
- Test Arabic and English on the same device.
- Test light and dark mode on all main screens.
- Deploy the latest Firestore rules and indexes.
- Build a release APK or AAB with a private signing key.
- Keep the signing key private and backed up.
- Publish `PRIVACY_POLICY.md` and `TERMS.md` in a public place and link them in app distribution notes.
- Test installation on at least two Android phones before sharing widely.

Firebase Cloud Messaging is intentionally not included in this version. Notifications use Firestore listeners plus local device notifications.
