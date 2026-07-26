# Cardiva — Defense Q&A: AI, Confidence Score, Emergency Logic

Answers are grounded directly in the current code, not the original planning blueprint —
where the two disagree, that's called out explicitly. File/line references let you pull
up the exact source during defense if challenged.

**Important architectural fact used throughout this document:** Cardiva actually has
**two parallel analysis engines**, not one:

| Engine | Files | Used by | What it is |
|---|---|---|---|
| **Continuous rule engine** | `vital_classifier.dart`, `health_status_engine.dart`, `confidence_engine.dart` | Live Vitals tab, emergency popup, `vital_provider.dart` | Pure if/else thresholds, no trained model |
| **AI Analysis engine** | `ml_service.dart` + `emergency_model_generated.dart` + `fall_model_generated.dart` | "AI Analysis" tab, `analysis_provider.dart` | Real trained ML models (see below), OR'd with the same threshold rules |

Know which engine a judge is looking at before answering — the two have different
confidence formulas and slightly different decision logic (detailed in Section 4/5 below).

**Two more architectural facts worth knowing up front, both covered in more depth below:**
- **The ML models are not deployed on any backend.** They're trained in Python,
  converted to plain Dart via `m2cgen`, and compiled directly into the app —
  inference runs on-device, with zero network dependency. Only the Groq LLM
  chatbot is a real hosted backend call. See Section 6.
- **The original blueprint planned Supabase/PostgreSQL and Hive; the shipped app
  uses neither.** The real backend is Firebase (Auth, Firestore, Realtime
  Database); local storage is `SharedPreferences` + `sqflite` (chat cache only).
  `CloudService` (the Supabase stub) is dead no-op code, never wired to real
  credentials. See Section 8.

---

## 1. Is This Actually "AI"?

### Q15. You call this an 'AI-Based' system. Where is the AI exactly?

Two places, and they're distinct:

1. **Trained ML models** (`ml_service.dart`, powering the "AI Analysis" tab):
   - A `GradientBoostingClassifier` (scikit-learn, 200 trees, learning_rate 0.05) trained
     on `human_vital_signs_dataset_2024.csv`, classifying patient vitals as
     High Risk / Low Risk from 9 features (HR, HRV, RR, SpO2, Age, Height, Weight,
     Gender, BMI).
   - An `LGBMClassifier` (LightGBM, 500 trees, max_depth 8) trained on labeled
     accelerometer window data, classifying Fall / Not Fall from 70 engineered
     features (mean/std/skew/kurtosis/FFT-domain stats per axis + magnitude,
     over a 100-sample window, 50-sample step).
   - Both were converted from the trained Python `.pkl` files into native Dart
     (via `m2cgen`) so they run on-device with no server round-trip and no TFLite
     interpreter — just the model's learned math, transpiled.
2. **The Groq LLM chatbot** (`chatbot_engine.dart` / `groq_service.dart`) — a hosted
   large language model for the conversational assistant and natural-language
   vital explanations.

The **continuous background monitor** (Live Vitals tab, emergency popup) is
**not** ML — it's the rule engine described in Section 2 below. Be precise about
which layer you're pointing to.

### Q16. Is this a machine learning model, or if/else rules with fixed thresholds?

**Both — deliberately, in different layers.** The always-on continuous monitor
(`VitalClassifier` + `HealthStatusEngine` + `ConfidenceEngine`) is if/else rules
against WHO/AHA/ESC clinical thresholds. The on-demand "AI Analysis" feature
(`MlService`) is trained ML, hybridized with the same threshold rules via OR logic
so neither path can silently miss something the other catches. Don't describe
Cardiva as "just rules" or "just ML" — it's explicitly both, layered by design.

### Q17. Did you train any model on any dataset? If not, why call it AI?

Yes, both models were trained on labeled datasets (see Q15 for the exact
architecture/features/dataset for each). Both were verified after conversion to
Dart: the vitals model's Dart output was checked against Python's
`model.decision_function()` on multiple test vectors and matched exactly; the
fall model's Dart output was checked against a from-scratch traversal of the
LightGBM model's raw tree structure and matched exactly on multiple test vectors.

### Q18. Difference between a 'rule-based system' and a 'machine learning system'? Which is Cardiva?

- **Rule-based**: explicit, human-authored if/else conditions and fixed numeric
  thresholds. Deterministic — the same input always gives the same output, and a
  human can read the code and know exactly why any decision was made. Doesn't
  learn from data; only changes if a developer edits it.
- **Machine learning**: a model's internal parameters (decision tree splits, in
  Cardiva's case) are learned automatically by fitting to a labeled training
  dataset, rather than hand-written. Can capture patterns in the data a human
  might not think to write as an explicit rule.

**Cardiva is a hybrid of both** — see the two-engine table at the top of this
document.

### Q19. Why did you choose rules instead of training a machine learning model? (for the continuous monitor)

For the always-on, safety-critical baseline monitor specifically:
- **Auditability** — every alert traces back to a specific WHO/AHA/ESC threshold
  number in `thresholds.dart`, so a clinician (or a judge) can verify exactly why
  it fired. A trained model's decision boundary is harder to justify line-by-line.
- **No training-data risk** — the thresholds come from established clinical
  literature, not a limited FYP-scale dataset that might not generalize.
- **Zero inference cost per reading** — simple comparisons, evaluated on every
  single incoming reading with no risk of a model call failing, timing out, or
  needing a fallback (relevant given the ML calls in `ml_service.dart` are indeed
  wrapped in try/catch for exactly this reason).

ML is layered on top specifically where it adds value rules can't easily capture:
multi-feature nonlinear risk combinations (vitals model) and time-series
accelerometer motion patterns (fall model).

### Q20. Not enough data to train a model, or a deliberate design choice?

Deliberate hybrid design — not purely a data limitation. That said, it's honest
to note the training dataset (`human_vital_signs_dataset_2024.csv`) is a public/
synthetic dataset of modest size, appropriate for demonstrating the ML pipeline
within FYP constraints, not a hospital-scale real-patient dataset. The rule
engine's existence is a deliberate safety-net choice independent of dataset size
— this is standard practice in medical device software generally (deterministic
rules for the guaranteed floor, ML for enhanced/deeper detection on top).

### Q21. If you had 6 more months, would you add real machine learning? What would it predict?

Yes. Concretely:
- **Personalized baselines** — a lightweight per-patient model learning each
  user's individual normal ranges, rather than population-level thresholds.
- **Sequence/time-series prediction** — an LSTM or 1D-CNN over rolling vitals
  windows to predict deterioration trending *before* any single threshold is
  crossed, instead of reacting only once a reading is already abnormal.
- **A larger, real (ethically-sourced/IRB-approved) patient dataset** in place of
  the current public dataset, to improve generalization beyond the training
  distribution.
- **On-device personalization of the fall model** to each user's individual gait/
  movement signature, to reduce false positives.

### Q22. Can a rule-based system really be called 'intelligent'? Defend the project's title.

"Intelligent" describes the system as a whole — gender/age/activity-adjusted
clinical thresholds, a 2×2 fall×vitals decision matrix, a trained ML layer, and
an LLM chatbot for reasoning and explanation — not a claim that every subroutine
is a neural network. Rule-based / expert systems are themselves a long-established
branch of AI (predating and coexisting with ML), and encoding real clinical
domain expertise (WHO/AHA/ESC guidelines, applied dynamically per patient) is a
legitimate form of that. Combined with the trained ML layer and the LLM
chatbot, "AI-based" accurately describes the overall system.

### Q23. What academic or industry term would you use instead of 'AI' if a judge challenges you on this?

- **"Hybrid intelligent system"** — rule-based expert system + machine learning,
  precisely what Cardiva is.
- **"Clinical decision support system (CDSS)"** — the standard health-informatics
  term for exactly this pattern: rules + ML + alerting on top of patient vitals.
- **"Expert system"** — if a judge wants to isolate just the threshold engine,
  this is the correct, well-established term for it (not a step down from "AI" —
  expert systems are a recognized AI subfield).

None of these are a retreat from "AI" — they're more precise descriptions of
what's inside the AI-based system.

---

## 2. The Confidence Score

**There are two different confidence formulas in the codebase — know which one
you're being asked about.**

### 2A. `ConfidenceEngine` (continuous monitor — matches the original blueprint exactly)

File: `lib/engine/confidence_engine.dart`. Used by the Live Vitals tab, emergency
popup, and `HealthStatusEngine`.

### Q24. How exactly is the confidence score calculated? Walk me through the formula step by step.

```
Step 1 — points per vital status, summed over HR, SpO2, HRV, RR:
    emergency → 30 pts   warning → 15 pts   stable → 5 pts   normal → 0 pts
    rawScore = sum of all 4 vitals' points        (0–120)

Step 2 — normalize:
    score = (rawScore / 120) * 100                (0–100)

Step 3 — activity multiplier:
    running        → score *= 0.85
    walking        → score *= 0.92
    resting/lying  → unchanged (*= 1.00)

Step 4 — clamp to [0, 100]
```

### Q25. Why does emergency = 30, warning = 15, stable = 5, normal = 0? Where do these numbers come from?

A hand-set severity weighting, not a value fitted/learned from data — say this
plainly if pressed further. The ratios are deliberate: emergency dominates the
score (30, six times a "stable" reading), warning is half of emergency (15),
stable is a small nudge above normal (5) to acknowledge a borderline reading
without over-alarming, and normal contributes nothing so it can't inflate
confidence in an active alert. Honest framing for a follow-up: this is a
heuristic, and a natural piece of future work is learning these weights from
labeled outcome data instead of hand-setting them.

### Q26. Why is the maximum raw score 120? What are the 4 things being added together?

Four vitals are monitored per reading — Heart Rate, SpO2, HRV, Respiration Rate
— each capable of contributing at most 30 points (its emergency-tier score).
4 × 30 = 120 is the theoretical ceiling (all four simultaneously in the emergency
tier), which is why Step 2 normalizes by dividing by 120.

### Q27. Why multiply by 0.85 during running and 0.92 during walking?

Because heart rate and respiration are *expected* to rise during exercise — the
same raw HR value is far less alarming while running than at rest. The
multiplier down-weights confidence during activity so expected exercise-elevated
vitals don't produce an over-confident false alarm. Running gets a larger
discount (0.85 → 15% reduction) than walking (0.92 → 8% reduction) because
running pushes vitals further from resting baseline.

### Q28. Doesn't reducing confidence during running make it HARDER to detect a real emergency while exercising — exactly when heart problems are more likely?

**This is a real, honestly-acknowledged tradeoff, not an oversight — answer it
directly rather than defensively.**

Worked example: if only SpO2 is in the emergency tier and the other 3 vitals are
normal, rawScore = 30 → normalized 25 → ×0.85 (running) = **21.25**. That's nowhere
near the blueprint's 70-point emergency cutoff. In fact, under the original
blueprint design (Section 8.3), reaching confidence ≥ 70 requires **at least 3 of
the 4 vitals simultaneously in the emergency tier while resting** (90/120 → 75 →
×1.0 = 75), and effectively all 4 while running (120/120 → 100 → ×0.85 = 85).
A single critically abnormal vital alone would never cross that gate — which is
exactly the flaw this question is pointing at.

**However — and this is the important part — the actual implemented decision
logic no longer uses that confidence gate at all.** Grep the codebase:
`emergencyConfidenceGate = 70.0` is defined in `thresholds.dart:68` but is
**never referenced anywhere else in the code.** The real `HealthStatusEngine.analyze()`
(and `MlService.analyze()`) instead compute:

```dart
vitalsHighRisk = any single vital at warning OR emergency tier   // no confidence involved
alertClass = emergency   if fallDetected && vitalsHighRisk
           = vitalsAlert if !fallDetected && vitalsHighRisk
```

So in the app as actually built, a single emergency-tier SpO2 reading during
running **does** set `vitalsHighRisk = true` and **does** produce a `vitalsAlert`
(or `emergency`, if combined with a fall) — regardless of what the confidence
score says. Confidence is computed and displayed to the user (`prediction_result_screen.dart`
shows it as a "High/Moderate/Low confidence — please verify manually" hint), but
it is **advisory only**, not a gatekeeper for whether an alert fires. This was a
deliberate correction from the original design: the answer to "would this design
miss a real emergency during exercise" is "the earlier confidence-gated design
risked exactly that, which is why alerting was decoupled from the confidence
score entirely."

### Q29. Why is 70 the exact cutoff between 'emergency' and 'warning'? Why not 60 or 80?

70 was the number specified in the original design (`thresholds.dart:68`,
`emergencyConfidenceGate`), chosen as a round, moderately conservative
"more likely than not, and then some" cutoff — not derived from a statistical
fit. As covered in Q28, this constant is defined but **unused** in the current
alerting decision, so in the shipped app there is no live 70-cutoff behavior to
defend numerically; the honest answer is that this threshold was part of the
original plan and was superseded by un-gated alerting once its false-negative
risk (Q28) was identified during development.

### Q30. Do you have any real data proving 70 is the correct cutoff, or is it a guess?

No statistical validation — it was a design-time heuristic, not derived from
labeled outcome data. Same honest framing as Q25/Q29: a good candidate for
future work (calibrating thresholds/weights against real labeled emergency
outcomes), but not something to claim empirical backing for.

### Q31. What happens to a genuine emergency if the confidence score is 69 instead of 70?

In the shipped app: **nothing different** — alerting doesn't check the
confidence score at all (Q28), so 69 vs. 70 vs. 40 has no effect on whether the
alert fires. If asked about the *original* blueprint design instead: at 69, the
case would have fallen to priority-3 ("any vital emergency AND confidence < 70")
and been downgraded to "warning" (no auto-alert) rather than priority-2
("emergency" tier). That distinction is exactly why the gate was removed.

### Q32. Is 'confidence score' the correct term, or should it be called a 'severity score' or 'risk score'?

Fair challenge — "confidence" more naturally implies "how sure the system is
this classification is correct," whereas this number is really measuring
**how severe** the detected vitals are (weighted by how many vitals are
abnormal and how activity context should discount that). "Severity score" or
"risk score" would arguably be more accurate terminology. Worth conceding this
directly if pressed — it doesn't change the underlying engineering, just the
label.

### 2B. `MlService._confidence()` (AI Analysis tab — different formula, separate from the above)

File: `lib/services/ml_service.dart:178-214`. For completeness, if a judge is
looking at the "AI Analysis" tab specifically instead of the Live Vitals tab:

```
base = 78 if the trained ML model executed without error, else 68
+ 7  if the ML model AND the threshold rules both flag high risk, for vitalsAlert/emergency
+ 3  if BMI is in the normal range [18.5, 25)
+ 5  if the accelerometer heuristic also fired, for emergency/fallAlert
+ 10 if SpO2 < 88 OR HRV < 15 (extreme vitals)
+ 8  if classification is normal AND SpO2 ≥ 95 AND HRV ≥ 50
clamp to [50, 98]
```

This formula is unrelated to the 30/15/5/0-points system above — don't conflate
the two if asked to "walk through the formula" without first clarifying which
screen/engine is meant.

---

## 3. Emergency Decision Logic

### Q33. What is the exact priority order your system uses to decide an emergency? List all 6 rules in order.

The **original blueprint** (`CARDIVA_BLUEPRINT.md`, Section 8.3) specified 6
priority-ordered rules:

| Priority | Condition | Result |
|---|---|---|
| 1 | Fall detected | emergency |
| 2 | Any vital emergency-tier AND confidence ≥ 70 | emergency |
| 3 | Any vital emergency-tier AND confidence < 70 | warning |
| 4 | Any vital warning-tier | warning |
| 5 | Any vital stable-tier | stable |
| Default | All normal | normal |

**The implemented code (`HealthStatusEngine.analyze()`, `MlService.analyze()`)
simplified this to an un-gated 2×2 matrix** (see Q28): fall × vitalsHighRisk →
{emergency, fallAlert, vitalsAlert, normal}, with `vitalsHighRisk` true if *any*
vital is at warning-or-above, no confidence gate. Be ready to present both,
explicitly noting the second is what's actually running.

### Q34. Why does a fall ALWAYS trigger an emergency, but a bad heart rate reading does NOT always trigger one?

A fall is a discrete physical event with a specific accelerometer signature
(sudden impact, or free-fall then impact — see `fall_model_generated.dart` /
the heuristic in `ml_service.dart:118-120`) that is inherently unambiguous and
immediately actionable — someone has physically fallen. A single heart-rate
reading, by contrast, is continuous and activity-dependent (100 bpm is normal
while running, abnormal at rest), so it's classified through gender/activity-
adjusted thresholds rather than a flat trigger.

### Q35. Why is SpO2 below 90% always an emergency, no matter what activity, while heart rate depends on activity?

Blood oxygen saturation doesn't have a physiologically legitimate reason to rise
during exercise the way heart rate does — a healthy person's SpO2 stays roughly
95-100% whether resting or exercising. So SpO2 has no activity-adjusted table in
`thresholds.dart` (unlike heart rate, which has separate resting/walking/
running/lyingDown threshold sets) — a low SpO2 means the same thing regardless
of what the patient is doing, per WHO hypoxemia guidance.

### Q36. If heart rate and SpO2 disagree — one says emergency, one says normal — which one wins, and why?

Neither "wins" by suppressing the other — `vitalsHighRisk` is an **OR** across all
four vitals (`lib/engine/health_status_engine.dart:22-23`): if *any single* vital
(HR, SpO2, HRV, or RR) is at warning-or-above, the whole reading is flagged
high-risk. This is a deliberate safety-first choice — a dangerous SpO2 reading
is never masked just because heart rate looks fine that moment, and vice versa.

### Q37. Can one single bad reading (2 seconds of bad data) trigger a false emergency alert?

Yes — checked directly in `vital_provider.dart:55`: every incoming `VitalReading`
is passed to `HealthStatusEngine.analyze()` individually and immediately, with
no averaging or multi-reading consensus step beforehand. A single noisy/artifact
reading crossing a threshold can trigger a flagged alert on its own.

### Q38. Do you average multiple readings before deciding, or act on just one reading at a time?

One reading at a time — confirmed, no smoothing/debounce logic exists in the
classification path (see Q37). The one mitigating mechanism that *does* exist is
in `emergency_trigger.dart:16-17`: a 5-minute cooldown (`_alertCooldown`) that
prevents repeat SMS/notification spam once an alert has already fired — but that
limits repetition, it doesn't prevent the *first* alert from firing on a single
noisy reading.

### Q39. What is the risk of too many false alarms? Have you measured how often your system would falsely alert?

The risk is real and stems directly from Q37/38 — no averaging means transient
sensor noise (a loose BLE contact, a motion artifact) can trigger a one-off
alert. No formal false-positive rate has been measured against a labeled test
set; this is an honest gap, not a hidden one, and a clear item for future work
(e.g., requiring N consecutive abnormal readings before alerting, or a rolling-
window majority vote).

### Q40. What is the risk of missing a real emergency because of a low confidence score?

For the **live app as shipped**: none from confidence specifically — see Q28/31,
alerting doesn't check confidence at all, so a genuinely low-confidence-looking
event still triggers `vitalsAlert`/`emergency` if any vital crosses a threshold.
The risk that *does* exist is the opposite direction of what this question
implies at first glance: because there's no confidence gate, the system leans
toward **over-alerting** (Q39) rather than silently dropping real emergencies
due to a low score. Worth stating plainly: the design tradeoff was consciously
made in favor of not missing emergencies, at the cost of higher false-alarm risk.

---

## 6. Where Are the Models Actually Deployed?

Not a numbered question in the original list, but the single most common source
of confusion, so it gets its own section — cover this before Q53 if the topic
comes up.

**The two trained ML models are not deployed on any server or backend.** The
pipeline is:

```
Train in Python (fyp_dataset1.py / Fall_Detection.py, in Colab)
  → save as vitals_model.pkl / fall_model.pkl
  → convert to plain Dart via m2cgen (cardiva_ml_models/convert_to_dart.py,
    convert_fall_to_dart.py)
  → generated Dart source compiled directly into the app
    (lib/engine/generated/emergency_model_generated.dart, fall_model_generated.dart)
  → runs on the phone's own CPU when the app calls emergencyModelScore()/fallModelScore()
```

No HTTP call, no inference server, no per-request cost, and it works fully
offline — this is exactly why a Firestore/network outage never affects the "AI
Analysis" tab's ability to classify vitals or falls; the model math is already
sitting inside the installed app.

**The one exception is the AI chatbot** (`groq_service.dart`), which genuinely
is a hosted backend call — an HTTPS request to Groq's cloud API with a key
stored in `.env`. If asked "is anything actually server-side," that's the honest
answer: the chatbot, and nothing else in the ML pipeline.

---

## 7. Mobile App / Software Architecture

### Q53. Why did you build this in Flutter instead of native Android or iOS?

Single Dart codebase targets Android, iOS, and web from one source tree — no
maintaining two parallel Kotlin and Swift implementations on an FYP timeline.
Hot reload gives fast iteration on UI-heavy screens (35+ screens in this app),
and the plugin ecosystem covers every hardware/service need used here —
`flutter_blue_plus` for BLE, the official `firebase_*` plugins, `pdf`,
`fl_chart` — without writing native platform channels by hand for most of it.

### Q54. What is Riverpod, and why did you use it instead of other state management options?

Riverpod is a reactive state-management and dependency-injection library for
Flutter (the compile-time-safe successor to the `Provider` package). Its
providers can be read/tested without a `BuildContext`, and missing/miswired
providers are caught at compile time rather than crashing at runtime.
Concretely in this app: `StreamProvider`s wrap live Firestore/RTDB streams
(`dailySummaryProvider`, `analysisHistoryProvider`, the chat streams in
`patient_chat_screen.dart`) so the UI reactively rebuilds on new data with no
manual `StreamBuilder` boilerplate repeated per screen. Compared to bare
`setState` (unworkable at 35+ screens), plain `Provider` (weaker compile-time
guarantees), or `Bloc` (more ceremony per feature), Riverpod was the better
fit for a small team's timeline.

### Q55. Explain your folder structure — why did you separate models, services, engine, and providers?

- **`models/`** — plain data classes (`VitalReading`, `UserProfile`, `AlertClass`).
  No logic, just shape.
- **`services/`** — the I/O boundary: talks to Firebase, `SharedPreferences`,
  `sqflite`, BLE, the Groq API. Nothing here makes clinical decisions, it only
  moves data in and out.
- **`engine/`** — the actual decision logic (`VitalClassifier`,
  `HealthStatusEngine`, `ConfidenceEngine`, `MlService`, `EmergencyTrigger`) —
  deliberately isolated from both I/O and UI.
- **`providers/`** — Riverpod glue wiring `services/` + `engine/` output into
  reactive state the `screens/` layer watches.

This is a layered-architecture separation: each layer can be tested, replaced,
or reasoned about independently — directly what makes Q57 (swapping mock data
for real hardware) a runtime switch instead of a rewrite.

### Q56. Why does your 'engine' folder avoid using any Flutter code?

So it's pure, plain Dart with zero dependency on the Flutter widget tree —
it can be unit-tested with `dart test` alone, no emulator/simulator required.
More importantly for a safety-critical app: it keeps the clinical decision
logic from ever accidentally depending on UI/widget state, which keeps that
logic isolated, auditable, and easy to verify in isolation — directly relevant
to the "is this auditable" theme raised in Section 1.

### Q57. How do you switch from fake data to real hardware data? Is it really a one-line change, and can you show it?

It's better than a one-line *code* change — it's a **runtime, automatic switch**,
not something you edit before building. From `lib/providers/vital_provider.dart`:

```dart
final latestReadingProvider = StreamProvider<VitalReading>((ref) {
  final bleConnected = ref.watch(bleConnectedProvider);
  final mock = ref.watch(mockDataServiceProvider);
  if (bleConnected) {
    mock.stop();          // real BLE stream takes over
    ...
  } else {
    ...                    // mock stream keeps running
  }
});
```

`bleConnectedProvider` flips to `true` the moment `BleService` reports a
connected wearable; the same running app build automatically stops generating
mock data and starts consuming live BLE readings, no rebuild or redeploy
needed. Disconnect the band and it falls back to mock data automatically too.

### Q58. What happens if the app crashes while an emergency is being processed?

Honest answer: there's no crash-recovery/replay mechanism for an in-flight
alert. `EmergencyTrigger.handle()` is a single async call chain (GPS lookup →
build message → send chat message + RTDB push) with no persistent "pending
alert" journal — if the process is killed mid-way, that specific alert attempt
is lost and nothing automatically retries it on next launch. This is a real
gap, not a hidden one, worth naming directly if asked and flagging as future
work (e.g., writing a pending-alert record to `SharedPreferences` before the
async work starts, and checking for/resuming one on next app start).

### Q59. Does the app work when there is no internet connection? What happens to unsaved data?

Partially, and it's important to be precise about which parts:
- **Local-only features keep working fully offline**: viewing analysis
  history/reports (`SharedPreferences`-backed), viewing cached chat messages
  (`sqflite`, `local_chat_db.dart`), and — critically — **the entire AI
  Analysis / ML inference pipeline**, since it has zero network dependency
  (Section 6).
- **Firebase writes queue rather than fail outright**: Realtime Database has
  `setPersistenceEnabled(true)` (`main.dart:19`), so writes made offline are
  queued locally and flush once connectivity returns; nothing is silently lost
  on the RTDB side.
- **Real-time features that need to reach another party don't work offline**:
  a guardian can't receive a new chat message or an emergency notification
  until *their* device also has connectivity, since the emergency alert path
  itself is Firestore + RTDB, not a phone-network SMS (see Section 9).

### Q60. Explain how Hive (local storage) is used in your app.

It isn't — this is a case where the original blueprint's plan and the shipped
app diverge. `hive` was never added as a dependency and is never referenced
anywhere in the codebase (verified directly — zero matches). Actual local
persistence uses `SharedPreferences` for almost everything (profile cache,
analysis history, manual guardian lists, chatbot session history) and
`sqflite` for exactly one thing: the offline chat message cache
(`lib/services/local_chat_db.dart`). If asked this in defense, the honest
answer is "we planned Hive originally but ended up using SharedPreferences and
a small SQLite cache instead" rather than describing Hive usage that doesn't
exist.

### Q61. What is the role of each file in your services folder?

Representative highlights (not exhaustive — there are ~20+ files):
- `firestore_service.dart` / `realtime_database_service.dart` — the two
  Firebase data-access layers (profile, roles, guardian linking, chat sessions).
- `link_service.dart` — resolves and maintains the patient↔guardian
  relationship (guardian snapshots, resolved UIDs).
- `chat_service.dart` — Firestore chat message streams and sends.
- `local_chat_db.dart` — the `sqflite` offline chat cache.
- `ble_service.dart` / `mock_data_service.dart` — the two interchangeable
  vitals data sources (Q57).
- `ml_service.dart` — the hybrid ML + threshold analysis engine.
- `groq_service.dart` — the LLM chatbot's API client.
- `pdf_report_service.dart` — generates shareable PDF health reports.
- `cloud_service.dart` — a dead Supabase stub, not actually used (Section 8).
- `sms_service.dart` — native SMS helper code that exists but is never called
  anywhere in the app (Section 9) — worth knowing it's there but inert.

---

## 8. Database (Supabase / PostgreSQL) — Corrected: It's Actually Firebase

**The original blueprint (Section 13/14) specified Supabase/PostgreSQL. That was
never actually implemented.** Verified directly in the code:
- `lib/services/cloud_service.dart` is explicitly commented
  `"Stub CloudService — all operations are no-ops during development. Replace
  method bodies with real Supabase calls once credentials are wired in."` —
  every method body is empty or returns an empty list.
- `lib/core/constants/api_endpoints.dart` has Supabase URL/anon-key constants
  that are never populated (`String.fromEnvironment` with no value ever set).
- The `supabase` package isn't even in `pubspec.yaml`.

**What's actually used is the Firebase suite**: `firebase_auth`,
`cloud_firestore`, `firebase_database` (Realtime Database), `firebase_storage`.
Answer all of the below in terms of Firebase, not Supabase/PostgreSQL — and say
so plainly if asked directly ("we planned Supabase originally, but built on
Firebase instead").

### Q62. Why did you choose Supabase instead of Firebase or building your own backend?

Correct the premise: the shipped app uses **Firebase**, not Supabase — Supabase
was the original plan, superseded during implementation. Reasonable framing:
Firebase's tight Flutter integration (official `firebase_*` plugins for every
service used here), built-in offline persistence for both Firestore and RTDB,
and no separate server to provision/maintain — all attractive for a small-team
FYP timeline versus standing up and maintaining a Postgres instance.

### Q63. Explain your database tables and how they connect to each other.

In actual Firestore/RTDB terms (see `firestore.rules` and `database.rules.json`
for the authoritative schema):
- `patients/{uid}` — patient profile + `guardian_snapshot.linked_guardians` +
  `manual_guardians`; subcollections `analysis_history/{docId}` and
  `health_reports/{docId}`.
- `guardians/{uid}` — guardian profile, readable by any signed-in user (so
  patients can resolve guardian names for chat), writable only by its owner.
- `chats/{chatId}` — `chatId` = the two participants' UIDs sorted and joined
  with `_`; a `participants: [patientUid, guardianUid]` array is how security
  rules and `arrayContains` queries link a chat back to its two users, plus a
  `messages` subcollection.
- Realtime Database mirrors profile/role data and resolved-guardian lookups
  for paths that need to work even when Firestore's WebSocket is blocked.

### Q64. If a reading is saved every 1 to 5 seconds per user, how much data would that be for 1,000 users in a month?

Note the premise first: readings aren't actually persisted every 1-5 seconds —
the continuous rule engine (`vital_provider.dart`) reacts to each live reading
for classification, but the "AI Analysis" pipeline that actually **saves** a
record runs on a 10-minute interval (`analysisIntervalMinProvider`, default 10
in `analysis_provider.dart`), not every few seconds. Using that real cadence:
1,000 users × 6 records/hour × 24h × 30 days ≈ 4.32M records/month. Each
record is a small JSON document (a handful of numeric fields + a timestamp) —
at, say, ~0.5KB each, that's roughly ~2GB/month of raw document storage,
comfortably within Firestore's free-tier document-count limits for a project
this size, though real production sizing would need to account for Firestore's
per-document-write pricing model, not just raw bytes.

### Q65. Does your database have security rules so a user can only see their own data, not other users' data?

Yes — `firestore.rules` enforces per-document ownership: `patients/{uid}` only
allows read/write from `isOwner(uid)` (or a specifically-linked guardian);
`chats/{chatId}` only allows access from `isParticipant()` (checked against the
`participants` array); a guardian can read another user's profile only when
actually linked. This isn't aspirational — it's live, checked directly in the
rules file (excerpted in Section 8 above).

### Q66. What happens to a user's data if they delete their account?

There is a real account-deletion flow — `profile_screen.dart`'s
`_deleteAccount()` calls `FirestoreService.deleteAccount()` after a confirming
dialog ("This will permanently delete your account and all health data. This
cannot be undone."). This is implemented, not a stub.

### Q67. Is there a limit on how much data Supabase can store for free, and what happens when you exceed it?

Not applicable — Supabase isn't used (Section 8). For the real backend,
Firebase's Spark (free) plan has its own Firestore/RTDB storage and read/write
quotas; exceeding them would require upgrading to the Blaze pay-as-you-go plan.
Worth having the correction ready rather than answering the Supabase-specific
version of this question as asked.

### Q68. You collect a feedback/accuracy rating from users — do you actually use that data anywhere, or is it just stored and ignored?

Honest answer: **it's stored and not yet used.** `saveFeedback()` exists in both
`firestore_service.dart` and `realtime_database_service.dart` and is called
from `feedback_sheet.dart`, but there is no corresponding read-back/aggregation
function anywhere in the codebase — no admin dashboard, no average-rating
display, nothing consuming it. If asked, say so plainly rather than implying
it feeds back into anything; a good "future work" answer is using it to
retroactively evaluate/tune the confidence-score weights discussed in Section 2.

---

## 9. Emergency Alert System — Corrected: No Real SMS Is Sent

**Important correction before answering any of these**: `CLAUDE.md` documents
"Emergency SMS Alerts via `url_launcher` (native SMS, no Twilio)" as
implemented. Checked directly: `lib/services/sms_service.dart` (which builds an
`sms:` URI and calls `launchUrl`) **is never called from anywhere in the app** —
zero call sites found. The actual emergency path,
`EmergencyTrigger.handle()` (`lib/engine/emergency_trigger.dart`), only does two
things: sends an in-app Firestore chat message to linked guardians
(`ChatService.sendMessage`), and pushes a Realtime Database notification
(`RealtimeDatabaseService.pushNotificationToUser`). **No real SMS/cellular text
message is sent to anyone.** `alert_sent_screen.dart` (the "who was notified"
confirmation screen shown after an alert) is purely a display screen reading
contacts from `SharedPreferences` to list them — it doesn't send anything
either.

Answer Q69-76 with this reality, not the SMS claim:

### Q69. What happens if the SMS fails to send during a real emergency?

There is no SMS send to fail — the actual notification is an in-app Firestore
chat message + an RTDB push. If *that* fails (e.g., the write can't reach the
server), it's wrapped in `.catchError((_) {})` per-contact in
`emergency_trigger.dart`, meaning a failure is silently swallowed with no
retry and no visible failure indicator to the patient. That's an honest gap:
worth stating directly if pressed, and a clear improvement target (surface a
"some contacts couldn't be notified" state instead of swallowing the error).

### Q70. Who pays for the SMS service (Twilio) costs, and how much does each message cost?

Not applicable — no SMS service (Twilio or otherwise) is actually used; the
notification is Firebase-based (Firestore write + RTDB push), which is
metered under Firebase's own pricing, not per-SMS.

### Q71. What happens if the user never gave location permission — does the emergency message still get sent, just without a location?

Yes — `EmergencyTrigger.handle()` wraps the GPS lookup in its own try/catch and
falls back to the literal string `'Location unavailable'` in the alert message
if `LocationService.getCurrentPosition()` throws (e.g., permission denied).
The alert itself is still sent either way — location is best-effort, not a
blocker.

### Q72. GPS often doesn't work well indoors. Since most falls happen indoors, how do you handle that?

Honestly: it isn't specifically solved. GPS is used as-is with graceful
degradation (Q71) — there's no indoor positioning fallback (Wi-Fi RTT,
Bluetooth beacons, cell-tower triangulation) implemented. Worth naming as a
known real-world limitation and a concrete future-work item rather than
claiming an indoor-accurate solution exists.

### Q73. If the internet or Bluetooth is down during an emergency, does the alert still work?

Depends which is down:
- **BLE down**: the live vitals/fall data stream stops (falls back to mock
  data per Q57), so automatic fall/vitals-triggered alerts can't fire from
  fresh sensor data. However, the manual SOS button
  (`EmergencyPopup`, called with `force: true` to bypass the alert cooldown)
  is a direct patient-triggered action that doesn't depend on a live BLE
  stream to fire.
- **Internet down**: the alert itself (Firestore chat message + RTDB push) is
  Firebase-based, so it cannot reach the guardian's device without
  connectivity on both ends. RTDB will queue the write locally (`main.dart:19`,
  `setPersistenceEnabled(true)`) and deliver it once connectivity returns, but
  there is no guaranteed-delivery channel (like real cellular SMS would be)
  that works with zero internet on either side.

### Q74. Is there a way for the emergency contact to confirm they received and understood the alert?

Not currently — the guardian receives an in-app chat message and a push
notification, but there's no read-receipt/acknowledgment flow feeding back to
the patient's app confirming the guardian saw and understood it (chat
`isRead` tracking exists for general messaging, but it isn't surfaced as an
emergency-specific "acknowledged" confirmation to the patient). A concrete,
named gap and future-work item.

### Q75. What is your legal or ethical responsibility if the app fails to send an alert during a real emergency?

Appropriate framing for an FYP defense: this is explicitly a prototype/proof-of-
concept, not a certified medical device, and should be presented to users with
that caveat — it is not a substitute for a certified medical alert system or
calling local emergency services directly. Given the real gaps just covered
(no delivery confirmation, no real SMS fallback, no crash-recovery), it would
be inaccurate and irresponsible to claim guaranteed delivery; the honest
position is that this is a supplementary notification layer, not a
guaranteed-delivery safety system.

### Q76. Can a user accidentally trigger a false emergency? What happens then, and can they cancel it?

The manual SOS path (`EmergencyPopup`) uses an animated countdown before
firing (`_AnimatedCountdown`), which functions as a brief cancellation window
before the alert is actually sent — check the exact countdown duration in
`emergency_popup.dart` if asked for the specific number. Once past that
countdown, the alert sends immediately with `force: true`. Automatic
(rule/ML-triggered) false positives are covered in Section 5, Q37-39 — a
single noisy reading can trigger an automatic alert, and there is a 5-minute
cooldown against repeat spam but no cancellation step for an
automatically-triggered alert the way there is for the manual SOS button.

---

## 10. Definitions — Plain-Language, On the Spot

### Q166. In simple words, what is SpO2, and why does it matter?

SpO2 is the percentage of your blood's oxygen-carrying capacity that's
actually carrying oxygen right now — a healthy reading is roughly 95-100%.
It matters because it's one of the most direct, fast-acting signals of a
breathing or circulation problem: a sudden drop means your organs (heart,
brain) may not be getting enough oxygen, often before you'd notice from
symptoms alone.

### Q167. In simple words, what is HRV (heart rate variability), and why is low HRV a bad sign?

Your heart doesn't beat at a perfectly even tempo — the tiny variation in time
between consecutive beats is HRV. Counter-intuitively, *more* variation is
healthy (it reflects a nervous system that's actively, flexibly regulating the
heart); low/flat variation can indicate the body is under significant stress
or that the heart's regulation is impaired, which is why Cardiva flags low
HRV as a warning sign rather than a good one.

### Q168. In simple words, what does BLE (Bluetooth Low Energy) mean, and how is it different from normal Bluetooth?

Bluetooth Low Energy is a version of Bluetooth designed for small devices that
need to run for a long time on a tiny battery — think fitness trackers, not
wireless headphones. It trades some data-transfer speed for dramatically lower
power use, which is exactly the trade-off a wearable health band needs: it
only has to send small numeric readings occasionally, not stream audio, so it
can run for days between charges.

### Q169. In simple words, what is a REST API?

A REST API is a standardized way for one piece of software to ask another for
data or to make it do something, over the same kind of connection your
browser uses to load a webpage. You send a request to a specific address (a
URL) saying what you want; the other side sends back a structured response
(usually JSON). Cardiva's chatbot talks to Groq's servers this way.

### Q170. In simple words, what is 'state management,' and why does an app need it?

State management is how an app keeps track of "what's currently true" —
is the user logged in, what's the latest heart-rate reading, is dark mode on —
and makes sure every screen that depends on that information updates
automatically when it changes. Without it, you'd have to manually tell every
single screen to refresh itself every time any piece of data changed anywhere
in the app, which gets unmanageable fast in an app with 35+ screens like this
one.

### Q171. In simple words, what is the difference between the cloud and local storage on the phone?

Local storage lives only on this specific phone — fast to access and works
with no internet, but it's gone if you uninstall the app or switch devices.
Cloud storage lives on a remote server (Firebase, in this case) — it's a bit
slower to reach and needs internet, but it's the same data no matter which
device you log in from, and it survives even if you lose your phone.

### Q172. In simple words, what does 'rule-based system' mean, for someone with zero coding background?

It means the app follows a fixed checklist of human-written conditions —
"if oxygen level is below this number, flag it as serious" — rather than
having learned those conditions itself from examples. Every rule was decided
and written by a person ahead of time, based on established medical
guidelines, so you can always point to the exact rule that caused any given
alert.
