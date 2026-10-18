# Išlik

Žaidybiška išgyvenimo, navigacijos ir pilietinio saugumo įgūdžių mokymosi programėlė (Flutter + Riverpod + go_router + Supabase).

## Paleidimas

```bash
flutter pub get
flutter test

# Be Supabase – pamokos įkeliamos iš assets/lessons/
flutter run

# Su Supabase
flutter run --dart-define=SUPABASE_URL=https://<projektas>.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=<raktas>
```

## Aplankų struktūra (feature-first + Clean Architecture sluoksniai)

```
lib/
├── main.dart                     # SharedPreferences + Supabase init, ProviderScope
├── app/                          # Programėlės „rėmas“ – žino apie visas funkcijas
│   ├── app.dart                  # MaterialApp.router, tema, lokalė (lt)
│   ├── router/
│   │   ├── app_router.dart       # GoRouter provideris, redirect, StatefulShellRoute
│   │   ├── routes.dart           # Visi maršrutų keliai
│   │   └── scaffold_with_nav_bar.dart
│   └── theme/app_theme.dart
├── core/                         # Infrastruktūra be verslo logikos
│   ├── config/env.dart           # --dart-define konfigūracija
│   ├── storage/                  # SharedPreferences provideris
│   ├── supabase/                 # Supabase init + klientas
│   └── utils/json.dart           # JSON pagalbinės funkcijos
├── features/                     # Kiekviena funkcija – atskiras modulis
│   ├── lesson/
│   │   ├── domain/models/        # Lesson, LessonItem (sealed), QuestionOption, LessonResult
│   │   ├── data/                 # LessonRepository: Asset / Supabase
│   │   ├── application/          # (vėliau) LessonSessionController – pamokos eigos Notifier
│   │   └── presentation/         # LessonScreen, LessonResultScreen, widgets/
│   ├── progress/domain/models/   # UserProgress (Supabase user_lesson_progress)
│   ├── onboarding/               # data/ (OnboardingController) + presentation/
│   ├── home/presentation/
│   ├── lesson_tree/presentation/
│   ├── guide/presentation/
│   └── profile/presentation/     # Profilis + Nustatymai
└── shared/widgets/               # Bendri UI komponentai

assets/lessons/                   # Pamokų JSON (PRD schema)
test/                             # Veidrodinė lib/ struktūra
```

**Priklausomybių taisyklė:** `presentation → application → domain ← data`. `domain` neimportuoja Flutter, Supabase ar Riverpod. Viena funkcija neimportuoja kitos funkcijos `presentation` sluoksnio – bendra logika keliama į `core/` arba `shared/`.

## Maršrutai

| Kelias | Ekranas | Pastaba |
| --- | --- | --- |
| `/onboarding` | OnboardingScreen | Redirect, kol nebaigta |
| `/home` | HomeScreen | 1 skirtukas |
| `/tree` | LessonTreeScreen | 2 skirtukas |
| `/guide`, `/guide/:cardId` | GuideScreen, GuideCardScreen | 3 skirtukas |
| `/profile`, `/profile/settings` | ProfileScreen, SettingsScreen | 4 skirtukas |
| `/lesson/:lessonId` | LessonScreen | Viso ekrano modalas virš skirtukų |
| `/lesson/:lessonId/result` | LessonResultScreen | `extra: LessonResult` |

## Modeliai

Modeliai – paprastos nekintamos Dart klasės su rankiniais `fromJson` / `toJson` (be kodo generavimo). `LessonItem` yra `sealed` klasė: kiekvienas JSON `type` turi savo potipį, o nežinomas tipas tampa `UnsupportedItem` ir yra praleidžiamas – todėl senesnė programėlės versija nelūžta gavusi naujesnį turinį.

## Užduočių tipai

Visi 8 PRD tipai turi UI (`lib/features/lesson/presentation/widgets/`): `info_card`, `single_choice` / `multi_choice`, `image_choice`, `scenario`, `order_steps`, `match_pairs`, `true_false`, `hotspot`.

`hotspot` turinyje privalo nurodyti `aspectRatio` (paveikslėlio plotis / aukštis): paveikslėlis ištempiamas į šį rėmą, kad santykinės koordinatės sutaptų. `targetAreas[].r` – spindulys pločio dalimis.

## Turinys: Supabase + offline

```
LessonTreeScreen / LessonScreen
        │  catalogProvider, lessonProvider
        ▼
ContentRepository ── 1. Supabase (SupabaseLessonRemoteDataSource)
        │            2. kešas    (FileLessonCache → content_cache/*.json)
        │            3. assets   (BundledContentSource → assets/catalog.json, assets/lessons/)
```

- **Katalogas** (kursai, skyriai, pamokų santraukos su `version`): tinklas → kešas → assets.
- **Pamoka**: jei kešo versija ≥ katalogo – iš kešo be tinklo; kitaip atsisiunčiama ir kešuojama; nepavykus – pasenusi kešo kopija, tada assets.
- `syncLessons(unitId:)` atsisiunčia tik pasikeitusias pamokas.
- Tinklo užklausų laiko riba – 8 s. Kešo klaidos pamokos nesustabdo.
- „Kelias“ ekranas rodo pranešimą, kai turinys ne iš serverio.

### Supabase paruošimas

1. `supabase link --project-ref <ref>` ir `supabase db push` – sukuria `courses`, `units`, `lessons` su RLS (`supabase/migrations/`).
2. Turinį rašo CMS / administratorius su `service_role` raktu. Programėlė mato tik `published` kursus / skyrius ir `approved` pamokas.
3. `lessons.content` – visas pamokos JSON; `id` ir `version` turi sutapti su eilute (DB apribojimas). Pakeitus turinį, `version` didinama – programėlės atnaujina kešą.
4. Paleidimas: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`

## Paskyros ir progresas

- **Svečias** – onboardinge sukuriamas Supabase anoniminis vartotojas (be ryšio – per pirmą sinchronizaciją). Profilyje jį galima **susieti su el. paštu**: ID nesikeičia, progresas lieka.
- Be Supabase raktų – vietinis svečias (`LocalGuestAuthRepository`), progresas tik įrenginyje.
- **Progresas – offline-first** (`ProgressService`):
  1. Užbaigus pamoką vietinis progresas (XP, žvaigždutės) atnaujinamas iškart, o bandymas (su UUID) įdedamas į eilę (`progress.json`).
  2. Eilė siunčiama per RPC `record_lesson_attempt` – iškart, paleidus programėlę, grįžus į ją ir profilyje patraukus žemyn.
  3. Nėra ryšio / laikina klaida – bandymai lieka eilėje; serverio atmesti (22xxx, 23xxx, P0xxx) – išmetami, kad eilė neužstrigtų.
  4. Ištuštinus eilę parsisiunčiamas `user_lesson_progress` – sujungtas iš visų įrenginių.
- Serveris pats skaičiuoja žvaigždutes, sumuoja XP ir ignoruoja pakartotinai atsiųstą bandymą, todėl pakartojimai ir keli įrenginiai nedubliuoja taškų.

- **Slaptažodis**: susietas svečias, patvirtinęs el. paštą (naršyklėje – grįžus į programėlę vartotojas atnaujinamas), profilyje raginamas nusistatyti slaptažodį (≥ 8 simboliai, raidės ir skaičiai). Supabase neatskleidžia, ar slaptažodis yra, todėl tai žymima `user_metadata.password_set` (tik UI žyma).

## Lygos

- 10 lygų (Pradinukas → Rangeris), grupės iki 30, savaitė – pirmadienis 00:00 Europe/Vilnius. Top 7 kyla, paskutiniai 5 krenta (1 lygoje nekrentama, 10-oje nekylama; mažoje grupėje kilimo zona turi pirmenybę).
- Į savaitės grupę patenkama uždirbus pirmą XP. XP į lygą ateina per trigerį ant `lesson_attempts` – pakartotiniai siuntimai nedubliuoja.
- `close_league_week(week)` uždaro savaitę (idempotentiška). Ji kviečiama ir tingiai – pirmo kreipinio naujoje savaitėje metu, todėl `pg_cron` nebūtinas (pavyzdys – migracijos pabaigoje).
- Klientas lentelių neskaito: `get_my_league()` grąžina tik savo grupę su slapyvardžiais („Žygeivis 1A2B3“).
- Profilyje – lygos kortelė, `/profile/league` – lentelė su kilimo / kritimo zonomis ir praėjusios savaitės rezultatu.

### Supabase nustatymai

- Authentication → Sign In / Providers: įjungti **Anonymous sign-ins** ir **Email**.
- Rekomenduojama įjungti CAPTCHA anoniminiams prisijungimams (apsauga nuo masinio paskyrų kūrimo).
- Authentication → Providers → Email: įjungti **Secure email change** ir pasirinkti slaptažodžio reikalavimus (raidės + skaičiai, ≥ 8).
- Migracija `…_progress.sql` sukuria `user_lesson_progress`, `lesson_attempts` ir funkciją `record_lesson_attempt` (RLS: tik savo duomenys, rašyti – tik per funkciją).

## Kiti žingsniai

- `LessonSessionController` (Notifier) vietoje `_LessonRunner` būsenos
- `syncLessons()` iškvietimas fone / mygtukas „Atsisiųsti skyrių“
- Širdelės, serija, XP įrašymas į Supabase
