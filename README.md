# tortotrack

A personal weight tracking app built with Flutter, inspired by the [Hacker's Diet](https://www.fourmilab.ch/hackdiet/) methodology. Track your morning weight, watch the trend line filter out the daily noise, and export your data whenever you want.

## Features

- Log your weight once per day — one tap in the morning
- Calendar-style table view, one month per page
- Trend graph using the Hacker's Diet exponential moving average
- Missing days handled via virtual interpolation (no fake data stored)
- CSV export of all your data
- Optional PDF export for a full-year overview
- Supports kg (default) and lbs
- 100% local storage — your data never leaves your device

## The Hacker's Diet Trend Formula

Raw weight fluctuates daily. The graph smooths it using an exponential moving average:

```
T_today = T_yesterday + 0.1 × (W_today − T_yesterday)
```

- `T` = trend value (the smooth line)
- `W` = actual weight you measured
- Each day the trend moves 10% toward today's weight

See [The Hacker's Diet by John Walker](https://www.fourmilab.ch/hackdiet/) for the full methodology.

## AI Disclaimer

This project was built with the assistance of [Claude AI](https://claude.ai) (Anthropic). All design decisions, specifications, and direction are by the repository owner. Code is reviewed and directed by a human.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free to use, study, and share for non-commercial purposes, with attribution to this repository.

## How to Run

Requires [Flutter](https://flutter.dev) SDK installed.

```bash
git clone https://github.com/c4ssiopeia/tortotrack.git
cd tortotrack
flutter pub get
flutter run
```
