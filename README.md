# lsm303dlhc-spin 
-----------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the LSM303DLHC 6DoF IMU

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or ~~[p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P)~~. Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read raw accelerometer, magnetometer data output, or scaled (micro-g's, micro-gauss, resp.)
* Set output data rate
* Set full-scale range
* Enable per-axis output (accel)
* Flags to indicate data is ready (accel, mag), or has overrun (accel)
* Set calibration offsets (accel)
* FIFO control and flag reading (accel; empty, full, number of unread samples)
* Single and double-click detection (accel; untested)

## Requirements

P1/SPIN1:
* spin-standard-library

P2/SPIN2:
* ~~p2-spin-standard-library~~

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* ~~P2/SPIN2: FastSpin (tested with 4.2.6)~~ _(not implemented yet)_
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [x] Add magnetometer support
- [ ] Add magnetometer calibration
- [ ] Add interrupt support
- [ ] Add click detection demo
- [ ] Port to P2/SPIN2
