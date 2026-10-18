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

## Kiti žingsniai

- `LessonSessionController` (Notifier) vietoje `_LessonRunner` būsenos
- Drift (SQLite) kešas pamokoms ir progreso sinchronizacijos eilė
- Širdelės, serija, XP įrašymas į Supabase
