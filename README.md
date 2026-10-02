# DPS Quantum Key Distribution over Free-Space Optical (FSO) Channels

**Python and GNU Octave simulation project** studying Differential Phase Shift Quantum Key Distribution (DPS-QKD) over terrestrial and satellite free-space optical links, with QBER analysis, classical post-processing, atmospheric turbulence, machine-learning-assisted optimization, trusted satellite relays, and a fictional banking application.

## Project information

| Information | Detail |
| --- | --- |
| Institution | Indian Institute of Technology Delhi (IIT Delhi), Bharti School of Telecommunication Technology and Management |
| Programme | Post Graduate Diploma in Advanced Communication Engineering with Quantum and AI Integration (PGDACEQAI), Batch 01 |
| Prepared by | **Limnesh Augustine** |
| Supervisor | **Prof. Neel Kanth Kundu** |
| Submission date | **9 October 2026** |
| Software | **Jupyter Notebook (Python)** and **GNU Octave** |
| Document status | **Institution Review** |
| Project report | [Read the formatted HTML report](https://limnesh.github.io/QuantumKeyDistribution-DPS/DPS_QKD_FSO_Project_Report-v1.0.html) |

## Project overview

This academic project develops a reproducible numerical framework for **Differential Phase Shift Quantum Key Distribution (DPS-QKD)** over **Free-Space Optical (FSO)** channels.

The report begins with the long-term confidentiality problem created by future quantum computers and introduces QKD as a quantum-safe key-distribution approach. **BB84, BBM92 and DPS** are presented as teaching protocols before the study concentrates on DPS-QKD for the main numerical analysis.

The project covers:

- **QKD fundamentals** and the roles of the quantum and authenticated classical channels.
- **BB84, BBM92 and DPS-QKD** protocol demonstrations.
- **QBER estimation** and error sources.
- **Information reconciliation** using syndrome/LDPC concepts.
- **Key verification** and **Toeplitz privacy amplification**.
- A detailed **DPS transmitter, interferometer and detector model**.
- Weak coherent pulses and **Poisson photon-number statistics**.
- A **20 km terrestrial FSO link** with optical link-budget analysis.
- **Log-normal atmospheric turbulence** and detection-weighted QBER.
- **Gauss-Hermite quadrature** and Monte Carlo validation.
- **Machine-learning-assisted parameter optimization** using an RBF kernel-ridge surrogate with physics-model rechecking.
- A **LEO satellite-to-ground DPS-QKD downlink**.
- A **two-ground-station trusted satellite relay**.
- A **multi-satellite trusted QKD network**.
- A fictional **Bahrain Sample Bank (BSB)** use case for studying QKD-assisted key delivery, encrypted replication, key management and phased quantum-safe adoption.
- **GNU Octave dashboards** for the numerical scenarios.

> **Research scope:** This is an educational engineering simulation. The modeled secret-key-rate values are comparative engineering proxies under the assumptions described in the report; they are not a complete composable finite-key security proof or a certified production QKD implementation.

## Main research questions

1. How do **distance, receiver aperture, mean photon number, interferometer visibility, detector background and atmospheric fading** affect DPS-QKD QBER and modeled secret-key-rate performance?
2. Does averaging a fluctuating optical channel before applying nonlinear detector/QBER/rate equations produce a different result from evaluating each fading state individually and then pooling the statistics?
3. Can a validated **machine-learning surrogate** identify useful DPS-QKD operating points while satisfying a QBER constraint, and do those points remain valid when rechecked using the original physics model?

## Simulation progression

| Stage | Study |
| --- | --- |
| 1 | DPS-QKD fundamentals, detector model and terrestrial FSO link |
| 2 | Atmospheric turbulence, fading statistics and outage behaviour |
| 3 | Machine-learning-assisted parameter search and physics revalidation |
| 4 | LEO satellite, trusted relay and multi-satellite network extensions |
| Application | Fictional Bahrain Sample Bank quantum-safe architecture case study |

## Project report

The complete formatted report includes the theory, worked calculations, equations, figures, simulation results, limitations, banking case study and references.

### 🌐 [Open the full HTML project report](https://limnesh.github.io/QuantumKeyDistribution-DPS/DPS_QKD_FSO_Project_Report-v1.0.html)

The GitHub Pages landing page is available here:

### 🔗 [https://limnesh.github.io/QuantumKeyDistribution-DPS/](https://limnesh.github.io/QuantumKeyDistribution-DPS/)

## Running the project

The repository contains the Python/Jupyter and GNU Octave implementations used for the project.

### Jupyter Notebook / Python

Open the relevant `.ipynb` notebook in Jupyter Notebook or JupyterLab and run the cells from top to bottom. The simulations expose the intermediate physical quantities as well as the final QBER and modeled-rate results so that the calculations remain reproducible and inspectable.

### GNU Octave

Open the project launcher or the relevant scenario `.m` file in the GNU Octave graphical application and execute it. The GNU Octave implementation provides GUI dashboards for the terrestrial, satellite, trusted-relay and multi-satellite scenarios.

> Keep the repository folder structure intact because notebooks and Octave launchers may depend on supporting files in their associated folders.

## Important interpretation notes

- QKD is used to **establish or supply key material**; the application data itself remains conventional encrypted traffic.
- QBER is an **observable error statistic** and does not by itself prove the presence of an eavesdropper.
- The project distinguishes the **physical click-conditioned detector model** from the separate **compact modeled QBER/SKR proxy**.
- Turbulence results use **detection-weighted pooling** because weak and strong fading states do not contribute equal numbers of detections.
- The ML model is a **surrogate of the physics simulation**, not a replacement for the physical model or a QKD security proof.
- Satellite trusted-relay scenarios require trust in the satellite or relay node and secure storage of hop-key material.
- The Bahrain Sample Bank case study is **fictional** and is intended only as an engineering application example.

## About the author

**Limnesh Augustine** is an Electronics and Communication Engineer and IT Project Manager at **GBM Bahrain**. He is also a licensed private pilot, an international 3D anamorphic artist and a Guinness World Record holder. His interests connect engineering, aviation, art and technology. He is pursuing studies at **IIT Delhi**, with a focus on advanced communications, quantum communication and free-space optical links.

---

*Academic project prepared by Limnesh Augustine for institutional review, October 2026.*
