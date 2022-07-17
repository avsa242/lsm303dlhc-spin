# lsm303dlhc-spin 
-----------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the LSM303DLHC 6DoF IMU

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read raw accelerometer, magnetometer data output, or scaled (micro-g's, micro-gauss, resp.)
* Set output data rate
* Set full-scale range
* Enable per-axis output (accel)
* Flags to indicate data is ready (accel, mag), has overrun (accel), has overflowed current scale setting (mag)
* Set calibration offsets (accel, mag)
* FIFO control and flag reading (accel; empty, full, number of unread samples)
* Single and double-click detection (accel)
* Interrupts: per-axis mask, threshold (accel)

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine
* sensor.imu.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.imu.common.spin2h (provided by p2-spin-standard-library)

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.14-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | NuCode      | FTBFS                 |
| P2        | SPIN2    | FlexSpin (5.9.14-beta) | Native code | OK                    |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* No support for DRDY or interrupt pins
* Hard-iron calibration non-functional

