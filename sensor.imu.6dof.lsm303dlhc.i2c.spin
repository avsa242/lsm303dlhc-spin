{
    --------------------------------------------
    Filename: sensor.imu.6dof.lsm303dlhc.i2c.spin
    Author:
    Description:
    Copyright (c) 2020
    Started Jul 29, 2020
    Updated Jul 29, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    XL_SLAVE_WR     = core#XL_SLAVE_ADDR
    XL_SLAVE_RD     = core#XL_SLAVE_ADDR|1
    MAG_SLAVE_WR    = core#MAG_SLAVE_ADDR
    MAG_SLAVE_RD    = core#MAG_SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF       = 3
    GYRO_DOF        = 0
    MAG_DOF         = 3
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

    R               = 0
    W               = 1

' XYZ axis constants used throughout the driver
    XAXIS          = 0
    YAXIS          = 1
    ZAXIS          = 2

' FIFO modes
    BYPASS          = %00
    FIFO            = %01
    STREAM          = %10
    STREAM2FIFO     = %11

VAR

    long _abiasraw[3], _mbiasraw[3], _ares

OBJ

    i2c : "com.i2c"                                             'PASM I2C Driver
    core: "core.con.lsm303dlhc.spin"                       'File containing your device's register set
    time: "time"                                                'Basic timing functions

PUB Null
''This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.MSleep (1)
                if i2c.present (XL_SLAVE_WR)                    'Response from device?
'                    if deviceid{}
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB Defaults{}
' Set factory defaults
    accelbias(0, 0, 0, W)
    accelscale(2)
    acceldatarate(50)

PUB AccelADCRes(bits) | tmp1, tmp2
' Set accelerometer ADC resolution, in bits
'   Valid values:
'       8:  8-bit data output, Low-power mode
'       10: 10-bit data output, Normal mode
'       12: 12-bit data output, High-resolution mode
'   Any other value polls the chip and returns the current setting
    tmp1 := tmp2 := $00
    readReg(core#CTRL_REG1, 1, @tmp1)
    readReg(core#CTRL_REG4, 1, @tmp2)
    case bits
        8:
            tmp1 &= core#MASK_LPEN
            tmp2 &= core#MASK_HR
            tmp1 := (tmp1 | (1 << core#FLD_LPEN))
        10:
            tmp1 &= core#MASK_LPEN
            tmp2 &= core#MASK_HR
        12:
            tmp1 &= core#MASK_LPEN
            tmp2 &= core#MASK_HR
            tmp2 := (tmp2 | (1 << core#FLD_HR))
        OTHER:
            tmp1 := (tmp1 >> core#FLD_LPEN) & %1
            tmp2 := (tmp2 >> core#FLD_HR) & %1
            tmp1 := (tmp1 << 1) | tmp2
            result := lookupz(tmp1: 10, 12, 8)
            return

    writeReg(core#CTRL_REG1, 1, @tmp1)
    writeReg(core#CTRL_REG4, 1, @tmp2)

PUB AccelAxisEnabled(xyz_mask) | tmp
' Enable data output for Accelerometer - per axis
'   Valid values: 0 or 1, for each axis:
'       Bits    210
'               XYZ
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG1, 1, @tmp)
    case xyz_mask
        %000..%111:
            xyz_mask := (xyz_mask >< 3) & core#BITS_XYZEN
        OTHER:
            return tmp & core#BITS_XYZEN

    tmp &= core#MASK_XYZEN
    tmp := (tmp | xyz_mask) & core#CTRL_REG1_MASK
    writereg(core#CTRL_REG1, 1, @tmp)

PUB AccelBias(axbias, aybias, azbias, rw)
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       axbias, aybias, azbias:
'           -1024..1023
'   NOTE: When rw is set to READ, axbias, aybias and azbias must be addresses of respective variables to hold the returned calibration offset values.
    case rw
        R:
            long[axbias] := _abiasraw[XAXIS]
            long[aybias] := _abiasraw[YAXIS]
            long[azbias] := _abiasraw[ZAXIS]

        W:
            case axbias
                -1024..1023:
                    _abiasraw[XAXIS] := axbias
                OTHER:

            case aybias
                -1024..1023:
                    _abiasraw[YAXIS] := aybias
                OTHER:

            case azbias
                -1024..1023:
                    _abiasraw[ZAXIS] := azbias
                OTHER:

PUB AccelData(ax, ay, az) | tmp[2]
' Reads the Accelerometer output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_L, 6, @tmp)

    tmp.word[XAXIS] := (tmp.word[XAXIS] << 16) ~> 20        ' LSM303DLHC accel data is 12bit,
    tmp.word[YAXIS] := (tmp.word[YAXIS] << 16) ~> 20        '   left-justified in a 16bit word
    tmp.word[ZAXIS] := (tmp.word[ZAXIS] << 16) ~> 20        '   shift to the top bit, then SAR enough to chop
                                                            '   the 4 LSBs off
    long[ax] := ~~tmp.word[XAXIS] - _abiasraw[XAXIS]
    long[ay] := ~~tmp.word[YAXIS] - _abiasraw[YAXIS]
    long[az] := ~~tmp.word[ZAXIS] - _abiasraw[ZAXIS]

PUB AccelDataOverrun
' Indicates previously acquired data has been overwritten
'   Returns:
'       Bits 3210 (decimal val):
'           3 (8): X, Y, and Z-axis data overrun
'           2 (4): Z-axis data overrun
'           1 (2): Y-axis data overrun
'           0 (1): X-axis data overrun
'       Returns 0 otherwise
    result := $00
    readReg(core#STATUS_REG, 1, @result)
    result := (result >> core#FLD_XOR) & %1111

PUB AccelDataReady
' Indicates data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    result := $00
    readReg(core#STATUS_REG, 1, @result)
    result := ((result >> core#FLD_ZYXDA) & %1) * TRUE

PUB AccelDataRate(Hz): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 0 (power down), 1, 10, 25, *50, 100, 200, 400, 1620, 1344, 5376
'   Any other value polls the chip and returns the current setting
    curr_rate := $00
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case Hz
        0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376:
            Hz := lookdownz(Hz: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376) << core#FLD_ODR
        OTHER:
            curr_rate := ((curr_rate >> core#FLD_ODR) & core#BITS_ODR)
            return lookupz(curr_rate: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376)

    curr_rate &= core#MASK_ODR
    curr_rate := (curr_rate | Hz) & core#CTRL_REG1_MASK
    writereg(core#CTRL_REG1, 1, @curr_rate)

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Reads the Accelerometer output registers and scales the outputs to micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := tmpx * _ares
    long[ptr_y] := tmpy * _ares
    long[ptr_z] := tmpz * _ares

PUB AccelScale(g) | tmp
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readreg(core#CTRL_REG4, 1, @tmp)
    case g
        2, 4, 8, 16:
            g := lookdownz(g: 2, 4, 8, 16)
            _ares := lookupz(g: 1_000, 2_000, 4_000, 12_000)

            g <<= core#FLD_FS
        OTHER:
            tmp := (tmp >> core#FLD_FS) & core#BITS_FS
            return lookupz(tmp: 2, 4, 8, 16)

    tmp &= core#MASK_FS
    tmp := (tmp | g) & core#CTRL_REG4_MASK
    writereg(core#CTRL_REG4, 1, @tmp)

PUB CalibrateAccel | tmpx, tmpy, tmpz, tmpbiasraw[3], axis, samples, orig_state
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up for this method to be successful
    tmpx := tmpy := tmpz := axis := samples := 0
    longfill(@tmpbiasraw, 0, 3)
    accelbias(0, 0, 0, W)
    orig_state.byte[0] := acceladcres(-2)
    orig_state.byte[1] := accelscale(-2)
    orig_state.word[1] := acceldatarate(-2)

    acceladcres(12)
    accelscale(2)
    acceldatarate(100)

    fifoenabled(TRUE)
    fifomode(FIFO)
    fifothreshold (32)
    samples := fifothreshold(-2)
    repeat until fifofull{}

    repeat samples
' Read the accel data stored in the FIFO
        acceldata(@tmpx, @tmpy, @tmpz)
        tmpbiasraw[XAXIS] += tmpx
        tmpbiasraw[YAXIS] += tmpy
        tmpbiasraw[ZAXIS] += tmpz + (1024000/_ares)         ' Assumes sensor facing up!

    accelbias(tmpbiasraw[XAXIS]/samples, tmpbiasraw[YAXIS]/samples, tmpbiasraw[ZAXIS]/samples, W)

    fifoenabled(FALSE)
    fifomode(BYPASS)

    acceladcres(orig_state.byte[0])
    accelscale(orig_state.byte[1])
    acceldatarate(orig_state.word[1])

PUB ClickAxisEnabled(mask): enabled_axes
' Enable click detection per axis, and per click type
'   Valid values:
'       Bits: 5..0
'       [5..4]: Z-axis double-click..single-click
'       [3..2]: Y-axis double-click..single-click
'       [1..0]: X-axis double-click..single-click
'   Any other value polls the chip and returns the current setting
    readreg(core#CLICK_CFG, 1, @enabled_axes)
    case mask
        %000000..%111111:
        OTHER:
            return

    writereg(core#CLICK_CFG, 1, @mask)

PUB Clicked: bool
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    bool := ((clickedint >> core#FLD_SCLICK) & %11) <> 0

PUB ClickedInt: active_ints
' Clicked interrupt status
'   Bits: 6..0
'       6: Interrupt active
'       5: Double-clicked
'       4: Single-clicked
'       3: Click sign (0: positive, 1: negative)
'       2: Z-axis clicked
'       1: Y-axis clicked
'       0: X-axis clicked
    readreg(core#CLICK_SRC, 1, @active_ints)

PUB ClickIntEnabled(enabled): curr_setting
' Enable click interrupts on INT1
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG3, 1, @curr_setting)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#FLD_I1_CLICK
        OTHER:
            return (curr_setting >> core#FLD_I1_CLICK) == 1

    curr_setting &= core#MASK_I1_CLICK
    curr_setting := (curr_setting | enabled)
    writereg(core#CTRL_REG3, 1, @curr_setting)

PUB ClickLatency(usec): curr_setting | time_res
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'       AccelDataRate:  Min time (uS, also step size)  Max time (uS)   (equiv. range in mS)
'       1               1_000_000                   .. 255_000_000     1,000 .. 255,000
'       10              100_000                     .. 25_500_000        100 .. 25,500
'       25              40_000                      .. 10_200_000       40.0 .. 10,200
'       50              20_000                      .. 5_100_000        20.0 .. 5,100
'       100             10_000                      .. 2_550_000        10.0 .. 2,550
'       200             5_000                       .. 1_275_000         5.0 .. 1,275
'       400             2_500                       .. 637_500           2.5 .. 637.5
'       1344            744                         .. 189_732         0.744 .. 189.732
'       1600            625                         .. 159_375         0.625 .. 159.375
'   Any other value polls the chip and returns the current setting
'   NOTE: Minimum unit is dependent on the current output data rate (AccelDataRate)
'   NOTE: ST application note example uses AccelDataRate(400)
    time_res := 1_000000 / acceldatarate(-2)                ' Resolution is (1 / AccelDataRate)
    readreg(core#TIME_LATENCY, 1, @curr_setting)
    case usec
        0..(time_res * 255):
            usec := (usec / time_res)
        OTHER:
            return (curr_setting * time_res)

    writereg(core#TIME_LATENCY, 1, @usec)

PUB ClickThresh(level): curr_thresh | ares
' Set threshold for recognizing a click, in micro-g's
'   Valid values:
'       AccelScale  Max thresh
'       2           1_984375 (= 1.984375g)
'       4           3_968750 (= 3.968750g)
'       8           7_937500 (= 7.937500g)
'       16         15_875000 (= 15.875000g)
'   NOTE: Each LSB = (AccelScale/128)*1M (e.g., 4g scale lsb=31250ug = 0_031250ug = 0.03125g)
    ares := (accelscale(-2) * 1_000000) / 128               ' Resolution is current scale / 128
    readreg(core#CLICK_THS, 1, @curr_thresh)
    case level
        0..(127*ares):
            level := (level / ares)
        OTHER:
            return curr_thresh * ares

    writereg(core#CLICK_THS, 1, @level)

PUB ClickTime(usec): curr_setting | time_res
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'       AccelDataRate:  Min time (uS, also step size)  Max time (uS)   (equiv. mS)
'       1               1_000_000                   .. 127_000_000     127,000
'       10              100_000                     .. 12_700_000       12,700
'       25              40_000                      .. 5_080_000         5,080
'       50              20_000                      .. 2_540_000         2,540
'       100             10_000                      .. 1_270_000         1,127
'       200             5_000                       .. 635_000             635
'       400             2_500                       .. 317_500             317
'       1344            744                         .. 94_494               94
'       1600            625                         .. 79_375               79
'   Any other value polls the chip and returns the current setting
'   NOTE: Minimum unit is dependent on the current output data rate (AccelDataRate)
'   NOTE: ST application note example uses AccelDataRate(400)
    time_res := 1_000000 / acceldatarate(-2)                ' Resolution is (1 / AccelDataRate)
    readreg(core#TIME_LIMIT, 1, @curr_setting)
    case usec
        0..(time_res * 127):
            usec := (usec / time_res)
        OTHER:
            return (curr_setting * time_res)

    writereg(core#TIME_LIMIT, 1, @usec)

PUB DeviceID{}: id
' Read device identification

PUB DoubleClickWindow(usec): curr_setting | time_res
' Set maximum elapsed interval between two consecutive clicks, in uSec
'   Valid values:
'       AccelDataRate:  Min time (uS, also step size)  Max time (uS)   (equiv. range in mS)
'       1               1_000_000                   .. 255_000_000     1,000 .. 255,000
'       10              100_000                     .. 25_500_000        100 .. 25,500
'       25              40_000                      .. 10_200_000       40.0 .. 10,200
'       50              20_000                      .. 5_100_000        20.0 .. 5,100
'       100             10_000                      .. 2_550_000        10.0 .. 2,550
'       200             5_000                       .. 1_275_000         5.0 .. 1,275
'       400             2_500                       .. 637_500           2.5 .. 637.5
'       1344            744                         .. 189_732         0.744 .. 189.732
'       1600            625                         .. 159_375         0.625 .. 159.375
'   Any other value polls the chip and returns the current setting
'   NOTE: Minimum unit is dependent on the current output data rate (AccelDataRate)
'   NOTE: ST application note example uses AccelDataRate(400)
    time_res := 1_000000 / acceldatarate(-2)                ' Resolution is (1 / AccelDataRate)
    readreg(core#TIME_WINDOW, 1, @curr_setting)
    case usec
        0..(time_res * 255):
            usec := (usec / time_res)
        OTHER:
            return (curr_setting * time_res)

    writereg(core#TIME_WINDOW, 1, @usec)

PUB FIFOEnabled(enabled) | tmp
' Enable FIFO memory
'   Valid values: FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    tmp := $00
    readreg(core#CTRL_REG5, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := (||enabled << core#FLD_FIFO_EN)
        OTHER:
            tmp := (tmp >> core#FLD_FIFO_EN) & %1
            return tmp * TRUE

    tmp &= core#MASK_FIFO_EN
    tmp := (tmp | enabled) & core#CTRL_REG5_MASK
    writereg(core#CTRL_REG5, 1, @tmp)

PUB FIFOEmpty | tmp
' Flag indicating FIFO is empty
'   Returns: FALSE (0): FIFO contains at least one sample, TRUE(-1): FIFO is empty
    readreg(core#FIFO_SRC_REG, 1, @result)
    result := ((result >> core#FLD_EMPTY) & %1) * TRUE

PUB FIFOFull | tmp
' Flag indicating FIFO is full
'   Returns: FALSE (0): FIFO contains less than 32 samples, TRUE(-1): FIFO contains 32 samples
    readreg(core#FIFO_SRC_REG, 1, @result)
    result := ((result >> core#FLD_OVRN_FIFO) & %1) * TRUE

PUB FIFOMode(mode) | tmp
' Set FIFO behavior
'   Valid values:
'       BYPASS      (%00) - Bypass mode - FIFO off
'       FIFO        (%01) - FIFO mode
'       STREAM      (%10) - Stream mode
'       STREAM2FIFO (%11) - Stream-to-FIFO mode
'   Any other value polls the chip and returns the current setting
    readreg(core#FIFO_CTRL_REG, 1, @tmp)
    case mode
        BYPASS, FIFO, STREAM, STREAM2FIFO:
            mode <<= core#FLD_FM
        OTHER:
            return (tmp >> core#FLD_FM) & core#BITS_FM

    tmp &= core#MASK_FM
    tmp := (tmp | mode) & core#FIFO_CTRL_REG_MASK
    writereg(core#FIFO_CTRL_REG, 1, @tmp)

PUB FIFOThreshold(level) | tmp
' Set FIFO threshold level
'   Valid values: 1..32
'   Any other value polls the chip and returns the current setting
    readreg(core#FIFO_CTRL_REG, 1, @tmp)
    case level
        1..32:
            level -= 1
        OTHER:
            return (tmp & core#BITS_FTH) + 1

    tmp &= core#MASK_FTH
    tmp := (tmp | level) & core#FIFO_CTRL_REG_MASK
    writereg(core#FIFO_CTRL_REG, 1, @tmp)

PUB FIFOUnreadSamples
' Number of unread samples stored in FIFO
'   Returns: 0..32
    readreg(core#FIFO_SRC_REG, 1, @result)
    result &= core#BITS_FSS

PUB Reset{}
' Reset the device

PRI readReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
'' Read num_bytes from the slave device into the address stored in buff_addr
    case reg_nr                                             ' Basic register validation
        $3220..$3227, $322E..$323D:                         ' Accel regs
        $3228..$322D, $3C03..$3C08:                         ' Accel/Mag data output regs
            reg_nr |= core#RD_MULTI
        $3C00..$3C02, $3C09..$3C0C, $3C31, $3C32:           ' Mag regs
        OTHER:
            return

    cmd_packet.byte[0] := reg_nr.byte[1]                    ' Use the slave address embedded in
    cmd_packet.byte[1] := reg_nr & $FF                      '   the upper byte of reg_nr
    i2c.start
    i2c.wr_block (@cmd_packet, 2)
    i2c.start
    i2c.write (reg_nr.byte[1] | 1)
    i2c.rd_block (buff_addr, nr_bytes, TRUE)
    i2c.stop

PRI writeReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg_nr                                                 ' Basic register validation
        $3220..$3226, $322E, $3230, $3232..$3234, $3236..$323D:
        $3C00..$3C02:
        OTHER:
            return

    cmd_packet.byte[0] := reg_nr.byte[1]
    cmd_packet.byte[1] := reg_nr & $FF
    i2c.start
    i2c.wr_block (@cmd_packet, 2)
    repeat tmp from 0 to nr_bytes-1
        i2c.write (byte[buff_addr][tmp])
    i2c.stop


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
