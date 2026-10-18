# Uždaras beta testavimas

PRD 7 sk.: 100–300 testuotojų (skautai, šauliai), TestFlight ir Google Play vidinis testavimas.

## 1. Supabase (beta projektas)

1. Sukurti atskirą **beta** projektą (ne produkcinį) ir pritaikyti migracijas: `supabase link --project-ref <ref>` → `supabase db push`.
2. Authentication:
   - Providers: **Anonymous sign-ins** ir **Email** įjungti; Email → **Secure email change**; slaptažodžio reikalavimai – raidės + skaičiai, ≥ 8.
   - URL Configuration → Redirect URLs: `lt.islik://auth-callback`.
   - Email Templates → Reset Password: įtraukti `{{ .Token }}` (programėlė prašo 6 skaitmenų kodo).
   - Rekomenduojama: CAPTCHA anoniminiams prisijungimams.
3. Turinys: įkelti pamokas (`lessons.status = 'approved'` tik eksperto patvirtintoms) ir gidą (`guide_books.published = true`).
4. Pranešimai apie klaidas: Studio → `content_reports_queue` (pavojingi patarimai – pirmi). Sutvarkius – `status = 'fixed'`.

## 2. Android pasirašymo raktas (vieną kartą)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # → ANDROID_KEYSTORE_BASE64
```

Raktą ir slaptažodžius laikyti slaptažodžių tvarkyklėje – praradus jį, programėlės Google Play atnaujinti nebus galima (nebent įjungtas Play App Signing – rekomenduojama).

Vietiniam build'ui – `android/key.properties` (ne git'e):

```properties
storeFile=/kelias/iki/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

## 3. GitHub paslaptys

Settings → Secrets and variables → Actions:

| Paslaptis | Kam |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | beta Supabase projektas |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | release pasirašymas |

## 4. Išleidimas

1. `pubspec.yaml` → `version:` (pvz., `0.1.0+1`; build numerį CI nustato pats).
2. Žyma: `git tag v0.1.0-beta.1 && git push origin v0.1.0-beta.1` (arba Actions → **Beta build** → Run workflow).
3. Workflow: testai → Android `app-release.aab` + `app-release.apk` (artefaktai, 30 d.) → iOS build'as be pasirašymo (patikrina, kad kompiliuojasi).
4. **Android**: Play Console → Testing → Internal testing → įkelti `.aab`, pridėti testuotojų el. paštus. (`.apk` – tik tiesioginiam diegimui komandos telefonuose.)
5. **iOS / TestFlight**: reikia Apple Developer paskyros ir sertifikatų. Paprasčiausia – **Codemagic** (Flutter, automatinis pasirašymas per App Store Connect API raktą) arba `fastlane match` + `pilot` GitHub Actions'e. Bundle ID: `lt.islik.app`.

`build/symbols` (artefakte) saugoti – be jų negalima iššifruoti obfuskuotų klaidų pėdsakų.

## 5. Testuotojams

- Įdiegti per Google Play kvietimą arba TestFlight.
- Klaidas ir netikslumus pranešti programėlėje: **Profilis → ⚙ → Pranešti apie klaidą**, arba vėliavėlės mygtuku pamokoje / gido atmintinėje (kontekstas pridedamas automatiškai; veikia ir be ryšio – išsiunčiama vėliau).

## 6. Prieš kviečiant testuotojus

- [ ] Eksperto patvirtintas visas beta turinys (pamokos + gidas), ypač pirmoji pagalba ir civilinė sauga; šaltinių nuorodos veikia.
- [ ] Privatumo politika (reikalinga abiejose parduotuvėse; vaikų iki 14 m. duomenys – PRD rizikos).
- [ ] Tikra piktograma ir užsklanda: pakeisti `assets/branding/*.png` → `dart run flutter_launcher_icons` → `dart run flutter_native_splash:create`.
- [ ] Patikrinta tikruose telefonuose: prisijungimas, laiško nuoroda (`lt.islik://auth-callback`), sinchronizacija be ryšio, „Skambinti 112“.
- [ ] Klaidų stebėjimas (Sentry, PRD 5 sk.) – dar neįdiegtas.
