# E-ink Fixer for KOReader

`einkfixer.koplugin` is a KOReader plugin designed to mitigate display degradation caused by "screen lines" on flexible e-ink panels, particularly Mobius-type screens.

## How It Works

Flexible e-ink screens (such as Mobius displays) can develop circuit damage in the TFT backplane over time, often due to bending or general wear. When this happens, the affected region loses its ability to maintain a stable voltage differential. After a screen refresh, pixels in that area gradually drift back toward black because no voltage is being actively applied—resulting in visible lines that mar the reading experience.

This plugin works around the issue by continuously refreshing a tiny rectangle in a corner of the screen—whether as a blinking dot, a hidden refresh area, or a small clock. It calls `Screen:refreshNoMergeUI()` exclusively on that rectangle and never triggers `partial` or `full` refreshes, so it won't interfere with KOReader's built-in full-refresh counter. The constant voltage pulses keep the surrounding circuitry active, helping the affected area hold its white state and reducing the visibility of lines.

The plugin has been tested on devices such as the **Kobo Forma** and **iReader Ocean 3 Plus**, with acceptable battery life impact.

> **Disclaimer**: The plugin author assumes no responsibility for any damage or malfunction caused by using this plugin. Use at your own risk.

## Options

- Enable/disable the fixer from `Tools -> More tools -> E-ink Fixer`
- Refresh style: blinking dot, hidden refresh area, or small clock
- Corner placement: top right or top left
- Clock mode: seconds or milliseconds
- Millisecond refresh interval: 50, 100, 250, or 500 ms

## Installation

Copy the entire `einkfixer.koplugin` folder into KOReader's `plugins` directory, then restart KOReader.
