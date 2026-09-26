# Security deployment requirements

This client now refuses cleartext API URLs, disables Android device backups,
does not log HTTP traffic outside debug builds, uses Firebase App Check on
mobile Apple/Android builds, and sends Firebase ID/App Check tokens to the
verification API. These are client safeguards, not DDoS protection: attackers
can call a public backend directly or modify a client app.

Before release, complete these required server and Firebase controls:

1. Register every production Android, iOS, macOS, and web app in Firebase App
   Check. Use Play Integrity for Android, DeviceCheck/App Attest for Apple, and
   build with `--dart-define=FBR_HELPER_RECAPTCHA_V3_SITE_KEY=<site-key>` for
   web. Monitor App Check metrics first, then enforce it for each Firebase
   product used by this app.
2. At the verification API gateway, require and verify both `Authorization:
   Bearer <Firebase-ID-token>` and `X-Firebase-AppCheck`. Reject missing,
   expired, invalid, revoked, and replayed credentials. Authorize every request
   from the verified Firebase UID; never trust a UID supplied in request data.
3. Put the API behind a managed DDoS/WAF service (for example Cloud Armor,
   Cloudflare, or an equivalent from the hosting provider). Keep the origin
   private so it only accepts traffic from that service. Enable bot filtering,
   TLS 1.2+, request-body limits, geo rules appropriate to the service, and
   automated alerting.
4. Enforce server-side rate limits and quotas before any expensive work. Use
   separate limits per IP, Firebase UID, App Check app ID, endpoint, and a
   global concurrency cap. Return `429` with `Retry-After`; do not retry
   non-idempotent requests automatically.
5. Validate CNIC/CPR format and length on the server, use parameterized database
   queries, restrict CORS to production origins, redact CNIC/CPR/tokens from
   logs, and keep secrets only in the server's secret manager.
6. Run dependency and vulnerability scanning in CI, sign release builds with
   non-debug keys, and rotate any credential that has ever been committed. The
   Android release build now refuses the debug key. Create an untracked
   `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and
   `keyPassword` that point to a protected release keystore.

The local SQLite database contains tax data. Android backup is disabled, but
database encryption at rest requires a deliberately planned SQLCipher migration
and is not interchangeable with the existing `sqflite` database. Do not claim
that rooted/jailbroken devices or compromised user endpoints are fully secure.
