DPS QUANTUM KEY DISTRIBUTION OVER FREE-SPACE OPTICAL (FSO) CHANNELS
==================================================================

This project simulates DPS-QKD over terrestrial and satellite FSO links.
It covers QBER, modeled secret-key rate (SKR), atmospheric turbulence,
ML-assisted optimization, trusted satellite relays and a banking use case.
It also introduces BB84, BBM92, E91, COW and QKD post-processing.
See the project report for calculations, results and limitations.

PROJECT REPORT (HTML)
  DPS_QKD_FSO_Project_Report_v1.0.html
  report-assets/                    Images used by the HTML report
  Open the HTML file in a browser, or use:
  https://limnesh.github.io/QuantumKeyDistribution-DPS/DPS_QKD_FSO_Project_Report_v1.0.html

PYTHON / JUPYTER
  DPS_QKD_FSO_v1.0.ipynb            Main simulation notebook
  Open in Jupyter Notebook or JupyterLab and select Run All.

GNU OCTAVE (GRAPHICAL INTERFACE)
  OctaveGUI_v1.0\START_PROJECT.m                  Project launcher
  Open the launcher in GNU Octave and run it to select a scenario.

The reported SKR is a modeled estimate, not a DPS-specific security proof.
