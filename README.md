# DPS Quantum Key Distribution over Free-Space Optical (FSO) Channels

**IIT Delhi PGDACEQAI final-semester project** | Python / Jupyter Notebook and GNU Octave

A numerical and educational study of **Differential Phase Shift Quantum Key Distribution (DPS-QKD)** over terrestrial and satellite free-space optical links. It combines optical-channel physics, quantum bit error rate (QBER), an illustrative modeled secret-key-rate (SKR) estimate, atmospheric turbulence, and machine-learning-assisted engineering optimization.

## Project information

| Information | Detail |
| --- | --- |
| Institution | Indian Institute of Technology Delhi (IIT Delhi), Bharti School of Telecommunication Technology and Management |
| Programme | Post Graduate Diploma in Advanced Communication Engineering with Quantum and AI Integration (PGDACEQAI), Batch 01 |
| Prepared by | **Limnesh Augustine** |
| Supervisor | **Dr. Neel Kanth Kundu** |
| Submission date | **9 October 2026** |
| Implementation | **Python / Jupyter Notebook** and **GNU Octave** |
| Document status | **Institution Review** |
| Project Report | [Full Project Report](https://github.com/limnesh/QuantumKeyDistribution-DPS/blob/main/DPS_QKD_FSO_Project_Report_v1.0.html) |
| Source repository | [QuantumKeyDistribution-DPS](https://github.com/limnesh/QuantumKeyDistribution-DPS) |

## Scope and main topics

- **Five QKD protocols:** BB84, BBM92, Ekert91 (E91), Coherent One-Way (COW), and DPS; includes Bell/CHSH testing, time-bin coherence monitoring, and differential-phase encoding.
- **Quantum-channel security:** authenticated classical discussion, illustrative Eve/QBER disturbance demonstration, and the distinction between a **5% engineering QBER limit** and the protocol-specific security analysis needed for DPS.
- **Classical post-processing:** Cascade, Winnow, LDPC and Polar reconciliation concepts; key verification and Toeplitz privacy amplification.
- **DPS transmitter and receiver:** weak coherent pulses, Poisson photon statistics, relative-phase encoding, one-slot-delay interferometry, two-port detection and raw click statistics.
- **20 km terrestrial FSO channel:** beam divergence, geometric aperture collection, atmospheric attenuation, pointing/tracking losses and optical/detector efficiency.
- **Atmospheric turbulence:** log-normal fading, detection-weighted QBER pooling and numerical integration using Gauss-Hermite quadrature.
- **Modeled key performance:** separate **raw detection rate**, **QBER** and **modeled SKR**, with a generic asymptotic entropy allowance.
- **ML-assisted optimization:** six-feature RBF surrogate, held-out validation, one-million-candidate screening, physics rechecking and comparison against a direct-physics search.
- **Space and networks:** LEO satellite-to-ground downlink, single trusted-satellite relay and three-satellite trusted route/key budgets.
- **Application case study:** fictional Bahrain Sample Bank (BSB) architecture for QKD-assisted key delivery and conventional encrypted communications.
- **GNU Octave:** companion numerical functions, interactive dashboards and comparisons with the Python model.

## Research questions

1. How do source intensity, receiver aperture, pointing loss, turbulence, interferometer visibility, and dark-count probability affect DPS-FSO raw detections, QBER and modeled SKR?
2. How does detection-weighted pooling across fading states compare with evaluating a nonlinear rate expression using an average transmission alone?
3. Can a six-parameter ML select a better **physics-verified** feasible design with the same number of direct physics evaluations—and what is the measured computational cost?

## ML optimization experiment

The latest Section 12 compares two optimization routes using an **equal budget of 300 direct physics evaluations** per method:

| Activity | Direct physics only | ML-assisted search |
| --- | ---: | ---: |
| RBF training targets | — | 150 physics evaluations |
| Independent hold-out tests | — | 100 physics evaluations |
| Candidate search | 300 physics evaluations | **1,000,000 ML predictions** |
| Final proposal verification | — | 50 physics evaluations |
| **Total direct physics evaluations** | **300** | **300** |

The six search inputs are **mean photon number (μ), receiver radius, pointing loss, log-normal turbulence strength, interferometer visibility and log10 dark-count probability**. Both routes maximize the same **modeled SKR** subject to **QBER < 5%**.

### Illustrative recorded results (one random seed)

| Metric | Physics-only search | ML-assisted search |
| --- | ---: | ---: |
| Physics-verified modeled SKR | ≈ **1,419 bit/s** | ≈ **1,918 bit/s** |
| Modeled QBER | ≈ 1.405% | ≈ 1.427% |

In this one seeded trial, surrogate screening identified an approximately **35.2% higher physics-verified modeled SKR**. **It did not achieve a runtime speedup:** the direct NumPy physics model is inexpensive, and RBF training/prediction added overhead. Repeated trials and expensive Monte Carlo propagation would be needed to establish broader optimizer benefits.

## Satellite key-budget interpretation

Satellite results are **accumulated modeled bits over a contact period**, not instantaneous bit/s:

| Scenario | Modeled integrated key budget | Interpretation |
| --- | ---: | --- |
| Single LEO pass | ≈ 95,195 bits in 7.42 min | ≈ 214 bit/s average over the pass |
| One trusted-satellite relay | ≈ 95,190 bits | Minimum of the two integrated satellite-ground link budgets |
| Three-satellite trusted chain | ≈ 74,009 bits | Bottleneck integrated link-key budget along the trusted route |

These are simplified, time-integrated simulation outputs subject to the model's trust, scheduling and storage assumptions.

## Running the project

### Python / Jupyter Notebook

Open the latest DPS-QKD `.ipynb` notebook in Jupyter Notebook or JupyterLab and **run cells in order**. Earlier physics-model functions must be executed before the ML sections. The numerical and plotting dependencies include NumPy, SciPy, pandas and Matplotlib. Use the environment documented by the notebook for other packages.

### GNU Octave

Open GNU Octave in the extracted Octave project directory, preserving its folder structure, and run:

```octave
run('START_PROJECT.m');
```

Use the dashboards to explore terrestrial and satellite cases and the **ML-versus-physics comparison**. Python and Octave may produce different randomly selected optimum designs because their random samples and numerical runtimes differ; use identical input matrices for a direct model-to-model comparison. A full Octave GUI runtime verification remains environment-dependent.

### Publishing the HTML through GitHub Pages

1. Upload `DPS_QKD_FSO_Project_Report_v1.0.html` to the repository root.
2. Upload the **entire** `report-assets/` folder alongside it, keeping image filenames and capitalization unchanged.
3. In **Settings → Pages**, select **Deploy from a branch**, branch **`main`**, folder **`/(root)`**, then save.
4. Open the report link in **Read the project report** above after the Pages deployment completes.

The report's equations, figures and table-of-contents navigation work in the HTML document without depending on an external image host.

## Scientific limitations

- This is an **educational numerical simulation**, not an experimentally validated or certified deployed QKD system.
- **Modeled SKR is not a DPS-specific composable finite-key security guarantee.** A positive model output or QBER below 5% does not by itself prove protocol security.
- The **~11% QBER reference** belongs to a particular ideal asymptotic BB84 security model, not to DPS-QKD.
- The illustrative Eve replacement example is a disturbance model; it does not characterize every physical attack.
- The six-feature search includes environmental/hardware conditions, not only independently adjustable engineering controls. A robust implementation must distinguish controllable settings from fixed operating scenarios.
- Satellite trusted-node networks require trusted relays, secure key storage, authenticated communication and realistic contact/scheduling analysis.
- The Bahrain Sample Bank case is **fictional**, supplied only to demonstrate a potential banking integration architecture.

## About the author

**Limnesh Augustine** is an Electronics and Communication Engineer and IT Project Manager at **GBM Bahrain**. He is also a licensed private pilot and an international 3D anamorphic artist and Guinness World Record holder. His interests connect engineering, aviation, art and technology. He is pursuing studies at **IIT Delhi**, with a focus on advanced communications, quantum communication and free-space optical links.

---

*Academic project prepared by Limnesh Augustine for institutional review, 20 September 2026.*
