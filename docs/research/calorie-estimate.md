# Estimating calories for a Run

Research for issue #6. Question: which formula should Paceline use to estimate calories burned on a Run from distance, moving time and body weight (no heart rate), and how accurate is it?

## TL;DR

- With no heart rate, every serious approach reduces to an **oxygen-cost-of-running model**: the ACSM running equation, Compendium MET look-ups, and the "1 kcal/kg/km" rule are all the same physiology at different resolutions.
- The ACSM level-running equation's **net** term works out to **exactly 1.0 kcal per kg per km**, independent of pace. That's the same number as the classic Margaria "1 kcal/kg/km" result. Moving time only matters if you add resting (gross) energy.
- Accuracy: on average the ACSM equation is within about 4% of measured energy for a 1600 m run (Hall et al. 2004). For an individual, expect roughly ±10–20%. Ruiz & Sherman (1999) found it over-predicts for most people. So label it as an estimate and round it.
- Grade adds a vertical term (0.9 × speed × grade). It is worth doing later, with barometric altitude. Leave it out of v1.

## Sources (by trust)

| Source | Type | Used for |
|---|---|---|
| ACSM's *Guidelines for Exercise Testing and Prescription*, metabolic calculations (running & walking equations) | Professional-body standard (textbook). The equations are reproduced verbatim in the validation literature below | Formulas |
| Herrmann SD et al. (2024) "2024 Adult Compendium of Physical Activities", *J Sport Health Sci* 13(1):6–12. [PubMed 38242596](https://pubmed.ncbi.nlm.nih.gov/38242596/), [PMC10818145](https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/) | Peer-reviewed reference standard | MET definition |
| [pacompendium.com: Running (12xxx codes)](https://pacompendium.com/running/) | Official Compendium site | Running MET values |
| Hall C, Figueroa A, Fernhall B, Kanaley JA (2004) "Energy expenditure of walking and running: comparison with prediction equations", *Med Sci Sports Exerc* 36(12):2128–34. [PubMed 15570150](https://pubmed.ncbi.nlm.nih.gov/15570150/) | Peer-reviewed validation (treadmill + track) | Accuracy |
| Ruiz A, Sherman NW (1999) "An evaluation of the accuracy of the ACSM metabolic equation for estimating the oxygen cost of running", *J Strength Cond Res* 13(3):219–223. [Abstract record](https://www.sponet.de/sponet/Record/4004686?lng=en) | Peer-reviewed validation | Accuracy (bias) |
| Margaria R, Cerretelli P, Aghemo P, Sassi G (1963) "Energy cost of running", *J Appl Physiol* 18:367–370 | Peer-reviewed classic (cited, not re-read) | 1 kcal/kg/km rule |
| Minetti AE et al. (2002) "Energy cost of walking and running at extreme uphill and downhill slopes", *J Appl Physiol* 93:1039–1046 | Peer-reviewed (cited from memory, not re-read) | Grade model |
| [Apple HealthKit `activeEnergyBurned` / `basalEnergyBurned`](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned) | First-party API docs | Gross vs net on iOS |

## The approaches

### 1. ACSM running equation (recommended basis)

```
VO2 (mL·kg⁻¹·min⁻¹) = 0.2 × S  +  0.9 × S × G  +  3.5
                       horizontal   vertical      resting
S = speed in m/min, G = grade as a fraction (0.05 = 5%)
```

- It is intended for running speeds above about 134 m/min (8 km/h, 5 mph). Below that, ACSM uses the **walking** equation: `VO2 = 0.1 × S + 1.8 × S × G + 3.5`.
- To convert to energy, use about **5 kcal per litre of O₂**, the ACSM convention. The true figure is 4.7–5.05 depending on fuel mix.
- `kcal = VO2 × body_kg / 1000 × 5 × minutes`
- Inputs: distance, moving time (for speed and for the resting term), body mass, and optionally grade.

**Key simplification for flat ground.** The net (horizontal) term is 0.2 mL O₂ per kg per metre:

```
0.2 mL/kg/m × 1000 m/km = 200 mL/kg/km = 0.2 L/kg/km × 5 kcal/L = 1.0 kcal/kg/km
```

So **net running energy on the flat = 1.0 × body_kg × distance_km**, whatever the pace. The resting term adds 3.5 mL/kg/min × 5 kcal/L, which is about **1.05 kcal per kg per hour** of moving time.

```
gross_kcal = body_kg × (1.0 × distance_km + 1.05 × moving_hours)
net_kcal   = body_kg × 1.0 × distance_km
```

### 2. Compendium METs

- 1 MET = 3.5 mL O₂·kg⁻¹·min⁻¹, which is about 1 kcal·kg⁻¹·h⁻¹ (Herrmann 2024). The values are **gross**: they include rest, so sitting is about 1.0–1.5 MET.
- `kcal = MET × body_kg × hours`. Net = `(MET − 1) × body_kg × hours`.
- Running codes are speed bands. Examples: 12050 at 6–6.3 mph = 9.3; 12060 at 6.7 mph = 10.5; 12070 at 7 mph = 11.0; 12080 at 7.5 mph = 11.8; 12090 at 8 mph = 12.0; 12120 at 10 mph = 14.8. There are also uphill and downhill rows (for example 12260, 6 mph at 5% incline = 13.3) ([pacompendium.com/running](https://pacompendium.com/running/)).
- Drawbacks: it is a step-function look-up table in mph bands. The Compendium itself says it "does not reflect precise individual EE values" and is a starting point rather than a personal estimate (Herrmann 2024). It adds nothing over the ACSM equation for a GPS app that knows exact speed.

### 3. "1 kcal per kg per km" rule of thumb

- This is Margaria et al. (1963): the net energy cost of running is about constant per unit distance across sub-maximal speeds. It is the same thing as the ACSM net horizontal term above, so it's not really a third method.
- Literature values cluster around 0.9–1.05 kcal/kg/km. Individual running economy varies noticeably even after normalising for mass.

## Worked example: 70 kg, 5 km in 26:15 moving time

Speed = 5000 m / 26.25 min = **190.5 m/min** (11.43 km/h, 7.10 mph, 5:15 /km). Flat ground.

| Method | Calculation | Result |
|---|---|---|
| ACSM **gross** | VO2 = 0.2×190.5 + 3.5 = 41.6 mL/kg/min (11.9 MET) → 41.6 × 70 / 1000 × 5 × 26.25 | **382 kcal** |
| ACSM **net** (= 1 kcal/kg/km) | 0.2×190.5 = 38.1 mL/kg/min → … × 26.25, or simply 70 × 5 | **350 kcal** |
| Compendium gross (12070, 7 mph, 11.0 MET) | 11.0 × 70 × 0.4375 h | 337 kcal |
| Compendium net | (11.0 − 1) × 70 × 0.4375 | 306 kcal |

The Compendium comes out lower than ACSM because its 7 mph band sits below the ACSM-implied 11.9 MET. That is consistent with Ruiz & Sherman's finding that ACSM tends to over-predict.

## Gross vs net (active) calories

- **Gross** includes the energy you would have burned anyway, sitting on the sofa: about 1 kcal/kg/h, or about 32 kcal in the example above.
- **Net / active** is the extra energy caused by running. Apple splits these into `activeEnergyBurned` and `basalEnergyBurned` in HealthKit, and the Fitness app's Move ring counts active calories.
- On the flat, net energy depends only on distance and mass, so moving time doesn't change it. Moving time still matters for:
  - picking walking vs running for slow segments
  - the resting term, if gross is shown
  - excluding pauses, so standing still adds nothing
- The difference is small for runs (about 8% here) but grows for slow or long efforts.

## Grade and elevation

- ACSM adds `0.9 × S × G` mL/kg/min for uphill running. `S × G × minutes` is the vertical metres climbed, so the term works out to 0.9 mL O₂/kg per metre of climb × 5 kcal/L, which is **0.0045 kcal per kg per metre climbed**. Speed doesn't enter into it.
- Example: a 2% average climb on the run above (100 m of ascent) gives 0.0045 × 70 × 100, which is **+31 kcal (about +9%)**.
- **Downhill:** the ACSM equation is not designed for negative grades. Minetti et al. (2002) show the cost of running falls on gentle descents, reaching a minimum around −20%, then rises again on steeper descents. Descending gives back much less energy than climbing costs. So for a loop that ends where it started (zero net elevation), calories still go up, not cancel. If grade is used, apply the uphill term to climbs and treat descents as flat. This is conservative and simple.
- **Practical:** GPS altitude is noisy. Raw noise would add phantom climbing and inflate calories. Grade should wait until barometric altitude (`CMAltimeter`) plus smoothing is in place.

## Accuracy

- **Group mean is good.** In Hall et al. (2004), 24 subjects ran 1600 m at 2.82 m/s on both a treadmill and a track; measured cost was about 480 kJ. The ACSM running equation's total error was about −20 kJ (about 4%), and ACSM and Léger were rated the most suitable running equations. Track and treadmill costs were nearly identical.
- **Bias for individuals.** Ruiz & Sherman (1999), with 33 adults doing 6-minute steady-state runs, found that ACSM significantly **over-estimated** oxygen cost, for 88% (29/33) of subjects.
- **Individual spread.** Running economy differs between people of the same mass. With only weight, distance and time, a realistic expectation is **±10–20% for an individual run**. That is fine for a "(EST)" label, but no decimals and no precision claims.
- **What we can't fix without sensors:** fitness and economy, wind, terrain or surface, and stop-and-go running inside a "moving" segment.

## What other trackers do without heart rate

Vendors don't publish their no-HR formulas. I did not find first-party documentation from Strava or Garmin, so the following is anecdotal (user forums):

- **Garmin:** without heart rate, it reportedly uses weight × activity type × duration look-ups. It reports active calories.
- **Strava:** reported to include resting (BMR) calories, so its numbers come out higher than Garmin's. Users widely describe its no-HR or no-power estimates as inflated.
- **Apple Fitness:** reports Active and Total calories separately, matching the HealthKit split.

Takeaway: there is no industry standard. The main visible choice is whether to show active or total.

## Recommendation

1. **Formula:** use the ACSM metabolic equation, computed per moving segment. Excluded pauses contribute 0.
   - Running segments (speed ≥ 134 m/min, about 8 km/h): `net kcal = 0.2 × S × kg / 1000 × 5 × min`. On the flat this equals **1.0 kcal × kg × km**.
   - Slower segments: use the walking equation net term `0.1 × S`.
2. **Show net (active) calories** as "CAL (EST)":
   - It matches Apple's "Active Calories" and HealthKit's `activeEnergyBurned`, which is the field to write if Paceline ever syncs to Health.
   - It doesn't credit the user for resting metabolism.
   - Worked example: 70 kg, 5 km, 26:15 → **350 kcal**. Gross would be 382 kcal.
3. **Ignore grade in v1.** Add the ACSM uphill term (`0.9 × S × G`, climbs only) later, once barometric altitude with smoothing is in place.
4. **Presentation:** round to the nearest 5 or 10 kcal and keep the "(EST)" label. Expect about ±10–20% per person. The formula tends to read high, not low.
5. **Required input:** body weight. If the user hasn't set it, show "—" rather than assume a default weight.
