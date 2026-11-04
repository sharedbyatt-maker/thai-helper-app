# BahtZay UI baseline

Baseline: master acb2c34ba73010313a84f3e2dc3a7c5810349a8a (PR #50 merged).
This is a review branch, not an approved production redesign.

## Preserve

- Existing icon, Burmese/English copy, four tab names and navigation order.
- Home direction tiles, selected-rate trend, 1/7/30-day controls, personal amount tool, share/alert/reminder flows.
- Calculator pay/receive modes, amount presets, deductions, up-to-three-rate comparison, result reveal, save/share.
- Wallet's available-after-reserves figure remains primary; do not relabel it as actual balance. Preserve balance, reserves, daily allowance, all three entry actions, plans, month controls and backup.
- History summaries, direction/completion/date filters, search, completion/edit/delete, backup/import and empty states.
- Calculation, storage, rates, notifications, admin and hosting behavior.

## Shared visual rules

Keep the existing emerald identity: primary #076B59; light canvas #F4F7F5; white surfaces; ink #173C33; supporting text #5B7068; borders #DCE7E1. Dark mode retains its existing palette.
Use Noto Sans Myanmar and existing symbol fallbacks. Main headings 22px/1.6, body about 1.65 line height; never force Burmese text into fixed-height single-line controls.
Use 16px page gutters and standard card corners, 14px inputs, 12px chip corners. App bar 60px, bottom navigation 76px with a clear selected label. Keep minimum touch targets at least 48px.
Replace the large trend-card gradient with a quiet solid brand surface while retaining all graph content and interactions. Keep every amount, label and source meaning unchanged.

## Review evidence

`test/design_render_test.dart` renders the real CurrencyApp, not a reconstructed HTML mockup or generated image. It reuses the established public-layout fixtures. Before and after use the same test/data and viewport sizes: 390px light, 375px dark, 320px at 1.4x text, 1440px desktop.
Fixture data are synthetic, isolated in mocked preferences and mocked rates HTTP. They never touch production data. Runtime timestamp labels can vary naturally between runs.
Screenshots and contact sheets are produced by the dedicated review workflow. Review production UI changes separately before merging this branch.
