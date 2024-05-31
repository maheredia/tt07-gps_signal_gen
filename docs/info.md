<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The gps signal generator is a configurable block capable used to test search algorithms for GPS receivers. It is composed by two main blocks:

- Register bank: a set of configuration registers with a uart rx interface for write-only  operations. These registers lets the user control: satellite ID, PRN code phase, doppler frequency, noise level, among others.

- Core: the core of the project is composed by a Gold Code generator, an NCO (numerically controlled oscillator) and PRNGs (pseudo random number generators). The core also provides a 1-bit message input to modulate the generated signal with a "navigation message".

## How to test

Clock frequency of the system should be set to 16.368 MHz. The register bank is configured with a uart interface at 115200 bauds.

## External hardware

A micropocessor or FPGA can be used to modulate the navigation message at the input. The output can be recorded for post-analysis or fed to the digital front end of a GPS receiver. The output is a 1-bit signal.
