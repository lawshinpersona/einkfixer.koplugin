# E-ink Fixer for KOReader

`einkfixer.koplugin` refreshes a very small rectangle in a top corner.

It calls `Screen:refreshNoMergeUI()` with only that rectangle. It never requests `partial` or `full`, so it should not advance KOReader's full-refresh counter.

## Options

- Enable or disable the fixer from `Tools -> More tools -> E-ink Fixer`.
- Style: blinking dot, hidden refresh area, or small clock.
- Corner: top right or top left.
- Clock mode: seconds or milliseconds.
- Millisecond refresh interval: 50, 100, 250, or 500 ms.

## Install

Copy the whole `einkfixer.koplugin` folder into KOReader's `plugins` folder, then restart KOReader.
