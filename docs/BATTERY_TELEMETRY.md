# Battery Telemetry

VibeStick records a lightweight power baseline once per minute while Wi-Fi is
connected and audio recording is inactive. Each sample contains firmware
version, uptime, battery voltage and percentage, charge and USB state, Wi-Fi
RSSI, and the Bridge receive time.

The authenticated endpoints are:

- `POST /telemetry/power` — firmware sample ingestion.
- `GET /telemetry/power/latest` — latest accepted sample.
- `GET /telemetry/power.csv` — export the current raw journal as CSV.

Samples are stored at
`~/Library/Application Support/VibeStick/Telemetry/power.jsonl`. The journal
rotates at 5 MiB to `power.previous.jsonl`. Battery percentage remains the
firmware's display estimate; voltage is the primary value for comparing runs.

Compare measurements only with similar screen settings, Wi-Fi signal,
firmware version, starting voltage, and room temperature. This baseline is not
a coulomb-counter capacity measurement.
