# Professional layout proposal — preview only

Source baseline: b29841e96cac19c75dae95287fb9509051f5952a, the current merged app.
Use the existing emerald identity and design tokens in UI_BASELINE.md. This proposal changes information hierarchy and grouping, not the app's feature set or calculations. Do not merge/deploy this proposal without explicit approval of these renders.

- Home: compact editorial heading; selected rate in a primary hero; source selector remains tied to the same quote; chart and 1/7/30-day controls on a separate, quieter surface. Keep direction tiles, amount tool and all existing sharing/alerts.
- Calculator: group direction, intention, amount, presets, quote and submit in one continuous form. Remove nested competing cards, keep numbering/fields, rate editing, comparisons, deductions and result reveal unchanged.
- Wallet: make spendable-after-reserves the main hero. Separate actual balance and reserves as supporting metrics. Put the existing daily calculation in its own supporting strip; preserve all three entry actions and planning.
- History: display the existing saved record name; place sent/received amounts side by side; keep search, all filters, completion/date controls, recalculate/delete and backup.

Every visible label remains from the app, except user-supplied saved names which are rendered literally. All monetary meanings, storage and API behavior remain unchanged. No new financial operation is added.

The render fixture uses two quote directions, seven illustrative history days, wallet/plan data and saved records. Both baseline and proposal use the exact same fixture. Sample data never touch production. Candidate and baseline source SHAs are recorded with the screenshots.

## V2 — a clear change in hierarchy

Compared with v1 (f0fb89a), keep the emerald identity but make the selected reference number the dominant Home figure. The actual chart is its own secondary surface and retains its fixed plotting height. Calculator submission is a persistent dock above the existing navigation; all labels and the result-reveal action are reused. The amount field distinguishes its numeric value from the currency suffix.

Wallet entry actions move next to the main task, with month navigation and transactions ahead of lengthy analysis/planning. The existing plan-edit action remains immediately accessible in the balance hero. Detailed plans and monthly calculations remain available lower on the same page. History search leads the filter area, status/date controls align where space permits, and records retain the v1 paired amounts. Introductory Home/history explanations remain accessible through a labeled info action; calculator mode guidance stays inline.

This is a preview, not an approved replacement. Do not merge/deploy. Use the same render fixtures for v1 and v2.
