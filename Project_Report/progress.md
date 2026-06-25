# CARDIVA Thesis — Formatting & Writing Progress

Target: `Project_Report/Thesis.docx` (Word COM engine; Python not installed).
Backups: `Project_Report/backups/Thesis_<timestamp>.docx` (made before every write).
Current state: **114 pages**, 21 tables, 14 figures, 6 chapters written (7–8 pending).

Rendering for visual QA: export to PDF via Word COM, rasterize pages with the Windows
WinRT `Windows.Data.Pdf` API (no poppler/ghostscript needed).

---

## FIXES BATCH — 2026-06-20 (from `fixes.txt`)

- [x] **#1 Author's Declaration** — three signatories present (Khansa Batool, Hafiza Sana,
      Ayesha Nadeem); Ayesha's block was left-aligned, now right-aligned to match the other
      two; whole declaration fits on one page (page iii).
- [x] **#2 Table of Contents** — chapters were mis-numbered (Introduction = "Chapter 3").
      Root cause: stale TOC + duplicate numbering. Fixed via #5; TOC refreshed. Now shows
      Chapter 1 Introduction (p1), Chapter 2 (p10), Chapter 3 (p22), Chapter 4 (p44) with
      1.1/1.2… subsections and on-line page numbers. Removed title-page lines that were
      polluting the TOC (converted those front-matter Heading lines to Normal, look preserved).
- [x] **#3 List of Abbreviations** — table constrained to within the right margin
      (120/295 pt cols); header changed from white-on-blue (unreadable) to dark bold on
      light blue.
- [~] **#4 Page borders** — NO page border, paragraph border, header/footer rectangle, frame,
      or text box exists anywhere in the file; rendered Introduction pages show no border.
      **Flagged for user**: likely Word's on-screen "Text Boundaries" view setting (does not
      print) or table gridlines. Need the user to point to the exact page.
- [x] **#5 Chapter title format** — was rendering "1  Chapter 1 Introduction" (duplicate
      number). Set the multilevel list level-1 format to "Chapter %1" and stripped the literal
      "Chapter N " from each title. Now reads bold "Chapter 1 Introduction" … "Chapter 4 System
      Design"; subsections stay 1.1/1.2. Numbering is now fully automatic (auto-restarts at 1).
- [x] **#6/#7 Headings + spacing** — all heading styles bold, sized by level (H1 16 / H2 14 /
      H3 13 / H4 12), keep-with-next on; H1 18 pt space-after (gap before first sub-heading);
      H2–H4 11 pt space-after; body keeps first-line indent + justified 1.5.
- [x] **#8 Objectives (1.5)** — numbered objective/scope/constraint items tightened to single
      spacing and left-aligned (removed the justified bold-lead-in stretching).
- [x] **#9 Space after tables/figures** — 12 pt before the paragraph following each table;
      12 pt after each figure caption.
- [x] **#10 Tables no-split** — every content-table row set "can't split"; use-case sub-tables
      sit on one page. (The 27-row abbreviations list legitimately spans 2 pages.)
- [x] **#11 Comparison table** — "Comparison of Cardiva with existing devices" now fits within
      the margins (cols locked, 9 pt font). It is a 6-column table on A4 portrait, so a few long
      words still wrap mid-word. **Option flagged**: rotate just that page to landscape, or
      convert to prose, if you prefer.
- [x] **#12 Blue table titles** — title/header rows (Typical/Alternative/Exception Course of
      Actions, Flow|Response, and the header rows of the abbreviation/vital/comparison tables)
      given subtle light-blue fill with dark bold text.
- [x] **#13 Extra spaces** — collapsed multiple spaces to one; trimmed trailing spaces before
      paragraph marks.
- [ ] **#14 In-text citations + references list** — **DEFERRED to the writing phase.** This
      requires generating citation markers and matching reference entries (content/writing,
      not formatting). Will be handled by the writing agent once chapter-writing rules are given.

## CH 5–6 FORMATTING BATCH — 2026-06-23

Backup before edits: `backups/Thesis_20260623_205945.docx`.

- [x] **Chapter auto-numbering** — Ch 5 & 6 already on the multilevel list (Chapter %1).
      They render bold centered "Chapter 5 / Implementation" and "Chapter 6 / Testing" on two
      lines with 5.1/5.2…/5.1.1 and 6.1…/6.5.1 sub-numbering. **Fix applied:** the new H1
      titles were missing the leading manual line break (vertical-tab char 11) that Ch 1–4
      use to drop the title under "Chapter N"; inserted it so they wrap identically (no prose
      change — only layout char).
- [x] **Heading styles/spacing** — new H1/H2/H3 inherit the existing styles (H1 16/center/18pt
      after, H2 14/left/11pt, H3 13/left/11pt, all bold + keep-with-next). No per-run overrides.
      Body inherits Normal: justified, 1.5 line spacing, 21.6 pt first-line indent. Verified.
- [x] **Tables (9 new: 5.1–5.6, 6.1–6.3)** — locked to fixed layout at 415 pt usable width
      (no autofit), even column widths, all within the right margin (max row width 414 pt).
      Wide tables (5.1 3-col, 6.2 6-col) reduced to 9 pt; all others 10 pt Times New Roman.
      Header row: light-blue fill (BGcolor 16574682) + dark bold text (color 3289650),
      heading-format/repeat on. Every content row set "can't split" (AllowBreakAcrossPages off).
- [x] **Captions** — all 9 were literal "Table 5.1:" text; converted to proper caption fields
      `Table {STYLEREF 1 \s}.{SEQ Table \* ARABIC \s 1}: title` so they (a) auto-number per
      chapter (5.1…6.3), (b) appear in the List of Tables via the existing `TOC \c "Table"`
      mechanism, and (c) render identically. Caption style retained, sits directly above its
      table. 12 pt space-before added on the Normal paragraph following each table (#9).
      Old Tables 1–9 keep their sequential `SEQ Table` numbering (unaffected by `\s 1`).
- [x] **Spacing/cleanup (#13)** — scoped Find/Replace over Ch 5–6: no multi-spaces or trailing
      spaces found (writer's text was clean). No em/en dashes present in Ch 5–6.
- [x] **Field refresh** — Track Changes off, 0 revisions; refreshed all fields, the TOC, the
      List of Figures, and the List of Tables. TOC now lists Chapter 5/6 + all subsections;
      List of Tables now includes Table 5.1 (p86) … Table 6.3 (p99) with page numbers. Page
      numbering continues correctly; final document = **114 pages**. Visually QA'd via PDF
      render (tables fit margins, captions above tables, blue headers, rows don't split).

## FLAGS — need your input / eyes
- **#4 border**: tell me which page shows it (I find none in the file; intro renders clean).
- **#11 comparison**: keep current fitted table, or go landscape / prose?
- **#14 references**: needs the writing phase.
- Diagrams: open in Word and confirm the 15 figures are watermark-free and crisp.

## TEMPLATE ALIGNMENT BATCH — 2026-06-24 (IST KICSIT FYP template)

User supplied the official IST/KICSIT FYP template. Aligned Ch 5 & 6 to it.

- [x] **Chapter 5 restructure** (backup `backups/Thesis_pre_ch5restructure_20260624_205720.docx`).
      Light restructure to template headings, content preserved:
      5.1 Software Components/Modules, 5.2 Hardware Components and Firmware (Vitals
      Computation + OLED demoted under it as 5.2.4 / 5.2.5), 5.3 Hardware-Software
      Integration, 5.4 Tools and Technologies. Fixed 3 stale `Section 5.1.5` cross-refs
      to `5.1.6` (classification pipeline). TOC/fields refreshed. 114 pp.
- [x] **Chapter 6 full rewrite** (backup `backups/Thesis_pre_ch6rewrite_20260624_213250.docx`).
      Rewrote all prose to template structure (headings already matched): 6.1 Introduction,
      6.2 Verification and Validation, 6.3 Test Cases/Suites/Scripts/Scenarios, 6.4 A Sample
      Testing Cycle, 6.5 Test Cases, 6.5.1 Sample Test Case. Reused Tables 6.1
      (troubleshooting) & 6.2 (representative cases) verbatim. **Rebuilt Table 6.3 into the
      template's exact test-case form** (Test Case id / Test Item / Author=Project Team /
      Documentation Date / Test Type / Test Case Name / Component / Release-Version /
      Description+Operation Procedure full-width / Pre+Post-conditions / Input+Expected) for
      the end-to-end fall-detection scenario. Method: spliced built OOXML into document.xml,
      validated well-formedness, refreshed via Word COM. 114 pp.
- [x] **Chapter 6 detailed test cases** (backup `backups/Thesis_pre_detailcases_20260624_215225.docx`).
      Added 6.5.2 Detailed Test Cases: expanded all 10 summary cases (TC-01..TC-10) into
      individual compact per-case tables (Tables 6.4-6.13: ID, Name, Objective, Precondition,
      Test Steps, Test Data/Input, Expected Result, Actual Result, Status). Status = Pass per
      user's real testing; TC-10 (respiration) = Qualitative/demo-grade. Light-blue label
      column. All grounded in code/firmware (no fabricated metrics). Now 31 tables, 119 pp.

## CHAPTER 7 — 2026-06-24 (backup `backups/Thesis_pre_ch7_20260624_221136.docx`)
- [x] **Chapter 7 — Conclusion** written + inserted after Ch 6. Auto-numbered "Chapter 7".
      Subsections: 7.1 Summary of the Work, 7.2 Achievement of Objectives, 7.3 Limitations,
      7.4 Future Work. Grounded in project (ESP32+Flutter, 6 vitals, 4-class, fall SM, SMS).
      121 pp.

## REFERENCES PASS — DONE 2026-06-24 (backup `backups/Thesis_pre_refs_20260624_222740.docx`)
- [x] Relocated the misplaced References block (was between Ch 4 and Ch 5) to the END, after
      Ch 7. Removed it + ~35 empty filler paragraphs (saved ~2 pp). Ch 4 content intact,
      flows straight into Ch 5. Verified (VitalSignAnalyzer class section present).
- [x] Rebuilt 8 entries [1]-[8] in clean IEEE format: fixed smart quotes, removed broken
      `](https://…` markdown artifacts + utm_source=chatgpt.com junk, fixed ISSN hyphens.
- [x] "References" heading = Heading1 with numId=0 (unnumbered, centered, no "Chapter 8");
      appears in TOC at p104 unnumbered (matches template).
- [x] In-text citations added surgically in Ch 3 (additive [n] before sentence period, no
      prose rewrite): [7] @ 3.1 wearables-interest sentence; [8] @ 3.1 multi-vital
      integration; [6] @ 3.3 AI/ML applications; [1],[2],[3],[4] @ 3.3 ML health-state
      classification (datasets); [5] @ 3.4 SMS emergency notification. Placed on GENERAL
      statements, not on the already-named works (Dias/Khalaf/Chan) -> no misattribution.
      All 5 Find/Replace returned True; verified literally in body. 119 physical pp.

## FORMATTING PASS — 2026-06-25 (rulebook: thesis-formatting-guide.md)
Audited full doc vs rulebook. Already-compliant (NOT touched): Normal TNR12 justified 1.5;
H1 16 center bold / H2-4 14/13/12 left bold; keep-with-next on; Caption TNR12 justified;
TOC1-3 single; Normal(Web) already justified TNR12; 3 sections (cover=NO number, front=roman,
content=arabic restart@1, footers unlinked); each chapter on a new page; captions above tables;
single List of Abbreviations; References unnumbered at end; Track Changes off / 0 revisions.
- [x] Fix 1: deleted 2 stray empty Heading 1 paragraphs before References.
- [x] Fix 2: locked Table 2 (Committee Members approval block) cant-split — all 31 tables now no-split.
- [x] Refreshed TOC + List of Tables/Figures + caption numbers (F9 equiv). 119 pp, 0 revisions.
- [ ] OPTIONAL not done: make chapter page-breaks robust (style-level pbBefore + remove 5 manual
      breaks). Current state renders correctly; left alone per user.
- [x] Abbreviations (handwritten note v/vi) — DONE 2026-06-25 (backup Thesis_pre_abbr_*).
      Margins verified Top/Bottom/Right=1in, Left=1.5in; no page border. Fixed redefinitions
      (rule "first instance only"): PPG 3x->1x (removed Ch3,Ch4 re-defs), BLE 3x->1x (removed
      Ch4,Ch5 re-defs); defined AI + GPS in Abstract (now AI=2 abstract+Ch1, GPS=2 abstract+Ch3).
      NOTE: Word COM had hung on a leftover Document-Recovery pane after a force-kill; fixed by
      `reg delete HKCU\...\Word\Resiliency /f` (Office 15.0). Style consistent (rule vi) already.
- [x] List of Abbreviations completeness (option A) — DONE 2026-06-25 (backup Thesis_pre_ablist_*).
      Added 7 abbreviations that were used+defined in text but missing from the front-matter
      table, alphabetically: I2C (Inter-Integrated Circuit), MVC (Model-View-Controller),
      PERS (Personal Emergency Response System), SDNN (Standard Deviation of Normal-to-Normal
      Intervals), SVM (Support Vector Machine), TLS (Transport Layer Security), UUID
      (Universally Unique Identifier). List now 33 entries.
- [x] Moved pre-existing out-of-order UI/UID into alphabetical position (now ...TLS, UI, UID,
      URL, UUID, WHO...). List fully alphabetical. (backup Thesis_pre_uifix_*)
- [x] Option B — DONE 2026-06-25 (backup Thesis_pre_optB_*). Spelled out at first PROSE use +
      added to List: JSON (Ch4), OLED/PDF/SDK/IMU (Ch5), HRV (Ch6), ERD (Ch4 heading "Entity
      Relationship Diagram (ERD) and Database Design"). Each defined once (ERD=2 = heading+TOC
      mirror, correct). List now 40 abbreviations. SKIPPED HR + RR by design: they appear only
      in code/diagram labels + table cells (JSON "hr"/"rr", transmitVitalSigns(HR:...), "Observe
      RR readout"); prose always uses full "heart rate"/"respiration rate", so a prose
      definition would be wrong. SpO2 + ESP32 = no action (already defined / product name).
- [ ] STILL MANUAL (visual): figure captions-below + diagrams watermark-free/clear (§3).

## WRITING — PENDING
- [x] **Chapter 5 — Implementation** — template-aligned (2026-06-24).
- [x] **Chapter 6 — Testing** — template-aligned + 10 detailed cases (2026-06-24).
- [x] **Chapter 7 — Conclusion** — written (2026-06-24).
- [x] **References pass** — relocated + cleaned to IEEE + in-text citations [1]-[8] in Ch 3 (2026-06-24).
