# G1-12 benchmark

Revision: aa85db5679d65f4ef45e762cddec0d1b3f83e2a5. Mode: baseline.

| Resolution | Vsync | Run | Valid | Active minimum | Frame median/p95/max ms | Tick median/p95/max ms |
|---|---|---|---|---|---|---|
| [1280, 800] | off | 1 | True | 36 | 325.65/434.06/63608.14 | 301.91/400.38/454.59 |
| [1280, 800] | off | 2 | True | 36 | 316.99/414.35/18364.23 | 303.14/399.01/455.21 |
| [1280, 800] | off | 3 | True | 36 | 328.02/26560.69/26560.69 | 304.04/396.57/458.76 |
| [1280, 800] | on | 1 | True | 36 | 339.99/461.00/461.00 | 303.64/399.36/455.56 |
| [1920, 1080] | off | 1 | True | 36 | 353.91/465.19/575.05 | 337.53/445.97/558.47 |
| [1920, 1080] | off | 2 | True | 36 | 322.28/409.88/6315.24 | 300.94/397.59/445.38 |
| [1920, 1080] | off | 3 | True | 36 | 324.70/425.10/474.71 | 307.64/405.86/456.04 |
| [1920, 1080] | on | 1 | True | 36 | 316.27/409.50/465.59 | 298.41/394.90/444.88 |

[
  {
    "resolution": [
      1280,
      800
    ],
    "runs": 3,
    "valid": true,
    "frame_p95_ms": [
      434.06,
      414.35,
      26560.692
    ],
    "tick_p95_ms": [
      400.38,
      399.006,
      396.569
    ],
    "frame_p95_variance": 151803609.79205424,
    "tick_p95_variance": 2.4833962222221873,
    "frame_p95_range": 26146.342,
    "frame_budget_ms": 16.7,
    "tick_budget_ms": 4.0,
    "meets_budget": false
  },
  {
    "resolution": [
      1920,
      1080
    ],
    "runs": 3,
    "valid": true,
    "frame_p95_ms": [
      465.187,
      409.88,
      425.104
    ],
    "tick_p95_ms": [
      445.97,
      397.591,
      405.857
    ],
    "frame_p95_variance": 544.1423682222227,
    "tick_p95_variance": 446.4341295555558,
    "frame_p95_range": 55.307000000000016,
    "frame_budget_ms": 20.0,
    "tick_budget_ms": 4.0,
    "meets_budget": false
  }
]

Raw reports include draw calls, rendered instances, memory, display, adapter, renderer, engine, activity windows and finite initial supplies. Frame intervals include main-thread stalls and presentation; they are not GPU-only durations. PNG readback frames are excluded.

Invalid workload runs remain listed and are not accepted for regression comparisons. Vsync-on references are separate from the three vsync-off runs. Profiling is separate because it changes timings.

## Suggestions

Run with consistent power/thermal state and quiescent user apps; compare valid runs only. Profile any budget miss before adding addons.
