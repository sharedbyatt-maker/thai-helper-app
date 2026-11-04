# Professional layout proposal — preview only

Source baseline: b29841e96cac19c75dae95287fb9509051f5952a, the current merged app.
Use the existing emerald identity and design tokens in UI_BASELINE.md. This proposal changes information hierarchy and grouping, not the app's feature set or calculations. Do not merge/deploy this proposal without explicit approval of these renders.

- Home: compact editorial heading; selected rate in a primary hero; source selector remains tied to the same quote; chart and 1/7/30-day controls on a separate, quieter surface. Keep direction tiles, amount tool and all existing sharing/alerts.
- Calculator: group direction, intention, amount, presets, quote and submit in one continuous form. Remove nested competing cards, keep numbering/fields, rate editing, comparisons, deductions and result reveal unchanged.
- Wallet: make spendable-after-reserves the main hero. Separate actual balance and reserves as supporting metrics. Put the existing daily calculation in its own supporting strip; preserve all three entry actions and planning.
- History: display the existing saved record name; place sent/received amounts side by side; keep search, all filters, completion/date controls, recalculate/delete and backup.

Every visible label remains from the app, except user-supplied saved names which are rendered literally. All monetary meanings, storage and API behavior remain unchanged. No new financial operation is added.

The render fixture uses two quote directions, seven illustrative history days, wallet/plan data and saved records. Both baseline and proposal use the exact same fixture. Sample data never touch production. Candidate and baseline source SHAs are recorded with the screenshots.
