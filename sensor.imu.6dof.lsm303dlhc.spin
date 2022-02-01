{
    --------------------------------------------
    Filename: sensor.imu.6dof.lsm303dlhc.i2c.spin
    Author: Jesse Burt
    Description: Driver for the ST LSM303DLHC 6DoF IMU
    Copyright (c) 2022
    Started Jul 29, 2020
    Updated Jan 16, 2022
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

    LSBF            = 0
    MSBF            = 1

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF       = 3
    GYRO_DOF        = 0
    MAG_DOF         = 3
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL      = 2
    CAL_G_SCL       = 0
    CAL_M_SCL       = 1_3
    CAL_XL_DR       = 100
    CAL_G_DR        = 0
    CAL_M_DR        = 75

    FP_SCALE        = 1_000_000

    R               = 0
    W               = 1

' XYZ axis constants used throughout the driver
    X_AXIS          = 0
    Y_AXIS          = 1
    Z_AXIS          = 2

' FIFO modes
    BYPASS          = %00
    FIFO            = %01
    STREAM          = %10
    STREAM2FIFO     = %11

' Magnetometer operating modes
    CONT            = 0
    SINGLE          = 1
    SLEEP           = 2

VAR

    long _abiasraw[ACCEL_DOF], _mbiasraw[MAG_DOF], _ares, _mres_xy, _mres_z

OBJ

    i2c : "com.i2c"                             ' PASM I2C engine
    core: "core.con.lsm303dlhc"                 ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
'This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    status := startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom I/O pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#TPOR)              ' wait for device startup
            if i2c.present(XL_SLAVE_WR)         ' test device bus presence
                return status
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.deinit{}

PUB Defaults{}
' Set factory defaults
    accelscale(2)
    magscale(1_3)
    magdatarate(15)

PUB Preset_Active{}
' Like Defaults(), but
'   * enables output data
'   * 50Hz accelerometer sample rate
    acceldatarate(50)
    accelscale(2)
    magopmode(CONT)
    magscale(1)

PUB Preset_ClickDet{}
' Presets for click-detection
    acceladcres(12)
    accelscale(4)
    acceldatarate(400)
    accelaxisenabled(%111)
    clickthresh(1_187500)
    clickaxisenabled(%11_00_00)
    clicktime(127_000)
    doubleclickwindow(637_500)
    clicklatency(150_000)
    clickintenabled(TRUE)

PUB AccelADCRes(bits): curr_res | tmp1, tmp2
' Set accelerometer ADC resolution, in bits
'   Valid values:
'       8:  8-bit data output, Low-power mode
'       10: 10-bit data output, Normal mode
'       12: 12-bit data output, High-resolution mode
'   Any other value polls the chip and returns the current setting
    tmp1 := tmp2 := 0
    readreg(core#CTRL_REG1, 1, @tmp1)
    readreg(core#CTRL_REG4, 1, @tmp2)
    case bits
        8:
            tmp1 &= core#LPEN_MASK
            tmp2 &= core#HR_MASK
            tmp1 := (tmp1 | (1 << core#LPEN))
        10:
            tmp1 &= core#LPEN_MASK
            tmp2 &= core#HR_MASK
        12:
            tmp1 &= core#LPEN_MASK
            tmp2 &= core#HR_MASK
            tmp2 := (tmp2 | (1 << core#HR))
        other:
            tmp1 := (tmp1 >> core#LPEN) & 1
            tmp2 := (tmp2 >> core#HR) & 1
            tmp1 := (tmp1 << 1) | tmp2
            return lookupz(tmp1: 10, 12, 8)

    writereg(core#CTRL_REG1, 1, @tmp1)
    writereg(core#CTRL_REG4, 1, @tmp2)

PUB AccelAxisEnabled(mask): curr_mask
' Enable data output for Accelerometer - per axis
'   Valid values: 0 or 1, for each axis:
'       Bits    210
'               XYZ
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#CTRL_REG1, 1, @curr_mask)
    case mask
        %000..%111:
            ' reverse the position of the XYZ bits, since internally, they're
            ' ZYX (XYZ order is sensor.imu standard)
            mask := (mask >< 3) & core#XYZEN_BITS
        other:
            return ((curr_mask & core#XYZEN_BITS) >< 3)

    mask := ((curr_mask & core#XYZEN_MASK) | mask)
    writereg(core#CTRL_REG1, 1, @mask)

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
            long[axbias] := _abiasraw[X_AXIS]
            long[aybias] := _abiasraw[Y_AXIS]
            long[azbias] := _abiasraw[Z_AXIS]
        W:
            case axbias
                -1024..1023:
                    _abiasraw[X_AXIS] := axbias
                other:
            case aybias
                -1024..1023:
                    _abiasraw[Y_AXIS] := aybias
                other:
            case azbias
                -1024..1023:
                    _abiasraw[Z_AXIS] := azbias
                other:

PUB AccelData(ax, ay, az) | tmp[2]
' Reads the Accelerometer output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_L, 6, @tmp)

    ' accel data is 12bit, left-justified in a 16bit word
    '   extend sign, then right-justify
    long[ax] := (~~tmp.word[X_AXIS] ~> 4) - _abiasraw[X_AXIS]
    long[ay] := (~~tmp.word[Y_AXIS] ~> 4) - _abiasraw[Y_AXIS]
    long[az] := (~~tmp.word[Z_AXIS] ~> 4) - _abiasraw[Z_AXIS]

PUB AccelDataOverrun{}: flag
' Flag indicating previously acquired data has been overwritten
'   Returns:
'       Bits 3210 (decimal val):
'           3 (8): X, Y, and Z-axis data overrun
'           2 (4): Z-axis data overrun
'           1 (2): Y-axis data overrun
'           0 (1): X-axis data overrun
'       Returns 0 otherwise
    flag := 0
    readreg(core#STATUS_REG, 1, @flag)
    return ((flag >> core#X_OR) & core#OR_BITS)

PUB AccelDataReady{}: flag
' Flag indicating accelerometer data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#STATUS_REG, 1, @flag)
    return (((flag >> core#ZYXDA) & 1) == 1)

PUB AccelDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 0 (power down), 1, 10, 25, *50, 100, 200, 400, 1620, 1344, 5376
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376:
            rate := lookdownz(rate: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376) << core#ODR
        other:
            curr_rate := ((curr_rate >> core#ODR) & core#ODR_BITS)
            return lookupz(curr_rate: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376)

    rate := ((curr_rate & core#ODR_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Reads the Accelerometer output registers and scales the outputs to micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := tmpx * _ares
    long[ptr_y] := tmpy * _ares
    long[ptr_z] := tmpz * _ares

PUB AccelInt{}: curr_state
' Read accelerometer interrupt state
'   Bit 6543210 (For each bit, 0: No interrupt, 1: Interrupt has been generated)
'       6: One or more interrupts have been generated
'       5: Z-axis high event
'       4: Z-axis low event
'       3: Y-axis high event
'       2: Y-axis low event
'       1: X-axis high event
'       0: X-axis low event
    readreg(core#INT1_SRC, 1, @curr_state)

PUB AccelIntMask(mask): curr_mask
' Set accelerometer interrupt mask
'   Bits:   543210
'       5: Z-axis high event
'       4: Z-axis low event
'       3: Y-axis high event
'       2: Y-axis low event
'       1: X-axis high event
'       0: X-axis low event
'   Valid values: %000000..%111111
'   Any other value polls the chip and returns the current setting
    case mask
        %000000..%111111:
            writereg(core#INT1_CFG, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#INT1_CFG, 1, @curr_mask)
            return

PUB AccelIntThresh(thresh): curr_lvl
' Set accelerometer interrupt threshold level, in micro-g's
'   Valid values: 0..16_000000
    case thresh
        0..16_000000:                           ' 0..16M micro-g's = 0..16 g's
        other:
            curr_lvl := 0
            readreg(core#INT1_THS, 1, @curr_lvl)
            case accelscale(-2)
                2: curr_lvl *= 16_000
                4: curr_lvl *= 32_000
                8: curr_lvl *= 62_000
                16: curr_lvl *= 186_000         ' Scale threshold reg's 7-bit
            return                              '   range to micro-g's

    case accelscale(-2)
        2: curr_lvl := 16_000
        4: curr_lvl := 32_000
        8: curr_lvl := 62_000
        16: curr_lvl := 186_000                 ' Scale micro-g's to threshold
                                                '   reg 7-bit range
    thresh /= curr_lvl
    writereg(core#INT1_THS, 1, @thresh)

PUB AccelScale(scale): curr_scl
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#CTRL_REG4, 1, @curr_scl)
    case scale
        2, 4, 8, 16:
            scale := lookdownz(scale: 2, 4, 8, 16)
            _ares := lookupz(scale: 1_000, 2_000, 4_000, 12_000)
            scale <<= core#FS
        other:
            curr_scl := (curr_scl >> core#FS) & core#FS_BITS
            return lookupz(curr_scl: 2, 4, 8, 16)

    scale := ((curr_scl & core#FS_MASK) | scale)
    writereg(core#CTRL_REG4, 1, @scale)

PUB CalibrateAccel{} | axis, orig_res, orig_scl, orig_dr, tmp[ACCEL_DOF], tmpx, tmpy, tmpz, samples
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up
'       for this method to be successful
    longfill(@axis, 0, 11)                      ' initialize vars to 0
    orig_scl := accelscale(-2)                  ' save user's current settings
    orig_dr := acceldatarate(-2)
    accelbias(0, 0, 0, W)                       ' clear existing bias

    ' set sensor to CAL_XL_SCL range, CAL_XL_DR Hz data rate
    accelscale(CAL_XL_SCL)
    acceldatarate(CAL_XL_DR)
    samples := CAL_XL_DR                        ' samples = DR, for 1 sec time

    ' accumulate and average approx. 1sec worth of samples
    repeat samples
        repeat until acceldataready{}
        acceldata(@tmpx, @tmpy, @tmpz)
        tmp[X_AXIS] += tmpx
        tmp[Y_AXIS] += tmpy
        tmp[Z_AXIS] += (tmpz-(1_000_000 / _ares))' cancel out 1g on Z-axis

    repeat axis from X_AXIS to Z_AXIS           ' calc avg
        tmp[axis] /= samples

    ' update offsets
    accelbias(tmp[X_AXIS], tmp[Y_AXIS], tmp[Z_AXIS], W)

    accelscale(orig_scl)                        ' restore user's settings
    acceldatarate(orig_dr)

PUB CalibrateGyro{}
' dummy method

PUB CalibrateMag{} | axis, orig_scl, orig_dr, tmpx, tmpy, tmpz, tmp[MAG_DOF], samples
' Calibrate the magnetometer
    longfill(@axis, 0, 10)                      ' initialize vars to 0
    orig_scl := magscale(-2)                    ' save user's current settings
    orig_dr := magdatarate(-2)
    magbias(0, 0, 0, W)                         ' clear existing bias

    ' set sensor to CAL_M_SCL range, CAL_M_DR Hz data rate
    magscale(CAL_M_SCL)
    magdatarate(CAL_M_DR)
    samples := CAL_M_DR                         ' samples = DR, for 1 sec time

    ' accumulate and average approx. 1sec worth of samples
    repeat samples
        repeat until magdataready{}
        magdata(@tmpx, @tmpy, @tmpz)
        tmp[X_AXIS] += tmpx
        tmp[Y_AXIS] += tmpy
        tmp[Z_AXIS] += tmpz

    repeat axis from X_AXIS to Z_AXIS           ' calc avg
        tmp[axis] /= samples

    ' update offsets
    magbias(tmp[X_AXIS], tmp[Y_AXIS], tmp[Z_AXIS], W)

    magscale(orig_scl)                          ' restore user's settings
    magdatarate(orig_dr)

PUB CalibrateXLG{}
' dummy method

PUB ClickAxisEnabled(mask): curr_mask
' Enable click detection per axis, and per click type
'   Valid values:
'       Bits: 5..0
'       [5..4]: Z-axis double-click..single-click
'       [3..2]: Y-axis double-click..single-click
'       [1..0]: X-axis double-click..single-click
'   Any other value polls the chip and returns the current setting
    case mask
        %000000..%111111:
            writereg(core#CLICK_CFG, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#CLICK_CFG, 1, @curr_mask)
            return

PUB Clicked{}: flag
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    return (((clickedint >> core#SCLICK) & core#CLICK_BITS) <> 0)

PUB ClickedInt{}: int_src
' Clicked interrupt status
'   Bits: 6..0
'       6: Interrupt active
'       5: Double-clicked
'       4: Single-clicked
'       3: Click sign (0: positive, 1: negative)
'       2: Z-axis clicked
'       1: Y-axis clicked
'       0: X-axis clicked
    readreg(core#CLICK_SRC, 1, @int_src)

PUB ClickIntEnabled(state): curr_state
' Enable click interrupts on INT1
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG3, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#I1_CLICK
        other:
            return ((curr_state >> core#I1_CLICK) == 1)

    state := ((curr_state & core#I1_CLICK_MASK) | state)
    writereg(core#CTRL_REG3, 1, @state)

PUB ClickLatency(ltime): curr_ltime | time_res
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
    time_res := 1_000000 / acceldatarate(-2)    ' Resolution is (1 / AccelDataRate)
    case ltime
        0..(time_res * 255):
            ltime := (ltime / time_res)
            writereg(core#TIME_LATENCY, 1, @ltime)
        other:
            curr_ltime := 0
            readreg(core#TIME_LATENCY, 1, @curr_ltime)
            return (curr_ltime * time_res)

PUB ClickThresh(thresh): curr_thr | ares
' Set threshold for recognizing a click, in micro-g's
'   Valid values:
'       AccelScale  Max thresh
'       2           1_984375 (= 1.984375g)
'       4           3_968750 (= 3.968750g)
'       8           7_937500 (= 7.937500g)
'       16         15_875000 (= 15.875000g)
'   NOTE: Each LSB = (AccelScale/128)*1M (e.g., 4g scale lsb=31250ug = 0_031250ug = 0.03125g)
    ares := (accelscale(-2) * 1_000000) / 128   ' Resolution is current scale / 128
    case thresh
        0..(127*ares):
            thresh := (thresh / ares)
            writereg(core#CLICK_THS, 1, @thresh)
        other:
            curr_thr := 0
            readreg(core#CLICK_THS, 1, @curr_thr)
            return curr_thr * ares

PUB ClickTime(ctime): curr_ctime | time_res
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
    time_res := 1_000000 / acceldatarate(-2)    ' Resolution is (1 / AccelDataRate)
    case ctime
        0..(time_res * 127):
            ctime := (ctime / time_res)
            writereg(core#TIME_LIMIT, 1, @ctime)
        other:
            curr_ctime := 0
            readreg(core#TIME_LIMIT, 1, @curr_ctime)
            return (curr_ctime * time_res)

PUB DeviceID{}: id
' Read device identification

PUB DoubleClickWindow(dctime): curr_dctime | time_res
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
    time_res := 1_000000 / acceldatarate(-2)    ' Resolution is (1 / AccelDataRate)
    case dctime
        0..(time_res * 255):
            dctime := (dctime / time_res)
            writereg(core#TIME_WINDOW, 1, @dctime)
        other:
            curr_dctime := 0
            readreg(core#TIME_WINDOW, 1, @curr_dctime)
            return (curr_dctime * time_res)

PUB FIFOEnabled(state): curr_state
' Enable FIFO memory
'   Valid values: FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG5, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#FIFO_EN
        other:
            return (((curr_state >> core#FIFO_EN) & 1) == 1)

    state := ((curr_state & core#FIFO_EN_MASK) | state)
    writereg(core#CTRL_REG5, 1, @state)

PUB FIFOEmpty{}: flag
' Flag indicating FIFO is empty
'   Returns: FALSE (0): FIFO contains at least one sample, TRUE(-1): FIFO is empty
    readreg(core#FIFO_SRC_REG, 1, @flag)
    return (((flag >> core#EMPTY) & 1) == 1)

PUB FIFOFull{}: flag
' Flag indicating FIFO is full
'   Returns: FALSE (0): FIFO contains less than 32 samples, TRUE(-1): FIFO contains 32 samples
    readreg(core#FIFO_SRC_REG, 1, @flag)
    return (((flag >> core#OVRN_FIFO) & 1) == 1)

PUB FIFOMode(mode): curr_mode
' Set FIFO behavior
'   Valid values:
'       BYPASS      (%00) - Bypass mode - FIFO off
'       FIFO        (%01) - FIFO mode
'       STREAM      (%10) - Stream mode
'       STREAM2FIFO (%11) - Stream-to-FIFO mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#FIFO_CTRL_REG, 1, @curr_mode)
    case mode
        BYPASS, FIFO, STREAM, STREAM2FIFO:
            mode <<= core#FM
        other:
            return ((curr_mode >> core#FM) & core#FM_BITS)

    mode := ((curr_mode & core#FM_MASK) | mode)
    writereg(core#FIFO_CTRL_REG, 1, @mode)

PUB FIFOThreshold(thresh): curr_thr
' Set FIFO threshold thresh
'   Valid values: 1..32
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core#FIFO_CTRL_REG, 1, @curr_thr)
    case thresh
        1..32:
            thresh -= 1
        other:
            return ((curr_thr & core#FTH_BITS) + 1)

    thresh := ((curr_thr & core#FTH_MASK) | thresh)
    writereg(core#FIFO_CTRL_REG, 1, @thresh)

PUB FIFOUnreadSamples{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 1..32
    readreg(core#FIFO_SRC_REG, 1, @nr_samples)
    return ((nr_samples & core#FSS_BITS) + 1)

PUB GyroAxisEnabled(mask)
' dummy method

PUB GyroBias(x, y, z, rw)
' dummy method

PUB GyroDataRate(rate)
' dummy method

PUB GyroData(x, y, z)
' dummy method

PUB GyroDataOverrun{}
' dummy method

PUB GyroDataReady{}
' dummy method

PUB GyroDPS(x, y, z)
' dummy method

PUB GyroScale(scale)
' dummy method

PUB MagBias(mxbias, mybias, mzbias, rw)
' Read or write/manually set Magnetometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       mxbias, mybias, mzbias:
'           -2048..2047
'   NOTE: When rw is set to READ, mxbias, mybias and mzbias must be pointers
'       to respective variables to hold the returned offset values.
    case rw
        R:
            long[mxbias] := _mbiasraw[X_AXIS]
            long[mybias] := _mbiasraw[Y_AXIS]
            long[mzbias] := _mbiasraw[Z_AXIS]

        W:
            case mxbias
                -2048..2047:
                    _mbiasraw[X_AXIS] := mxbias
                other:

            case mybias
                -2048..2047:
                    _mbiasraw[Y_AXIS] := mybias
                other:

            case mzbias
                -2048..2047:
                    _mbiasraw[Z_AXIS] := mzbias
                other:

PUB MagData(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_H_M, 6, @tmp)
    long[mx] := ~~tmp.word[0] - _mbiasraw[X_AXIS]
    long[my] := ~~tmp.word[2] - _mbiasraw[Y_AXIS]
    long[mz] := ~~tmp.word[1] - _mbiasraw[Z_AXIS]

PUB MagDataOverrun{}: flag
' Flag indicating magnetometer data has overrun
' Dummy method

PUB MagDataRate(rate): curr_rate
' Set Magnetometer Output Data Rate, in Hz
'   Valid values: 0 (0.75), 1 (1.5), 3, 7 (7.5), *15, 30, 75, 220
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CRA_REG_M, 1, @curr_rate)
    case rate
        0, 1, 3, 7, 15, 30, 75, 220:
            rate := lookdownz(rate: 0, 1, 3, 7, 15, 30, 75, 220) << core#DO
        other:
            curr_rate := ((curr_rate >> core#DO) & core#DO_BITS)
            return lookupz(curr_rate: 0, 1, 3, 7, 15, 30, 75, 220)

    rate := ((curr_rate & core#DO_MASK) | rate)
    writereg(core#CRA_REG_M, 1, @rate)

PUB MagDataReady{}: flag
'   Flag indicating new magnetometer data available
'       Returns: TRUE(-1) if data available, FALSE otherwise
    readreg(core#SR_REG_M, 1, @flag)
    return ((flag & core#DRDY_BITS) == 0)

PUB MagEndian(endianness): curr_order
' Choose byte order of magnetometer data
' Dummy method

PUB MagGauss(mx, my, mz) | tmp[MAG_DOF]
' Read the Magnetometer output registers and scale the outputs to micro-Gauss (1_000_000 = 1.000000 Gs)
    longfill(@tmp, 0, MAG_DOF)
    magdata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[mx] := tmp[X_AXIS] * _mres_xy
    long[my] := tmp[Y_AXIS] * _mres_xy
    long[mz] := tmp[Z_AXIS] * _mres_z

PUB MagInt{}: intsrc
' Magnetometer interrupt source(s)
' Dummy method

PUB MagIntLevel(active_state): curr_state
' Set active state of INT_MAG pin when magnetometer interrupt asserted
' Dummy method

PUB MagIntsEnabled(enable_mask): curr_mask
' Enable magnetometer interrupts, as a bitmask
' Dummy method

PUB MagIntsLatched(enabled): curr_setting
' Latch interrupts asserted by the magnetometer
' Dummy method

PUB MagIntThresh(level): curr_thr
' Set magnetometer interrupt threshold
' Dummy method

PUB MagLowPower(enabled): curr_setting
' Enable magnetometer low-power mode
' Dummy method

PUB MagOpMode(mode): curr_mode
' Set magnetometer operating mode
'   Valid values:
'       CONT (0): Continuous conversion
'       SINGLE (1): Single conversion
'       SLEEP (2, 3): Power down
    case mode
        CONT, SINGLE, SLEEP, 3:
            mode &= core#MR_REG_M_MASK
            writereg(core#MR_REG_M, 1, @mode)
        other:
            curr_mode := 0
            readreg(core#MR_REG_M, 1, @curr_mode)
            return (curr_mode & core#MD_BITS)

PUB MagOverflow{}: flag
' Flag indicating magnetometer measurement has overflowed the set range
' Dummy method

PUB MagPerf(mode): curr_mode
' Set magnetometer performance mode
' Dummy method

PUB MagScale(scale): curr_scl
' Set full scale of Magnetometer, in Gauss
'   Valid values: *1 (1.3), 2 (1.9), 3 (2.5), 4, 5 (4.7), 6 (5.6), 8 (8.1)
'   Any other value polls the chip and returns the current setting
    case scale
        1, 2, 3, 4, 5, 6, 8:
            scale := lookdown(scale: 1, 2, 3, 4, 5, 6, 8)
            _mres_xy := lookup(scale: 0_000909, 0_001169, 0_001492, 0_002222, {
}           0_002500, 0_003030, 0_004347)
            _mres_z := lookup(scale: 0_001020, 0_001315, 0_001666, 0_002500, {
}           0_002816, 0_003389, 0_004878)
            scale <<= core#GN
            writereg(core#CRB_REG_M, 1, @scale)
        other:
            curr_scl := 0
            readreg(core#CRB_REG_M, 1, @curr_scl)
            curr_scl := (curr_scl >> core#GN) & core#GN_BITS
            return lookup(curr_scl: 1, 2, 3, 4, 5, 6, 8)

PUB MagSelfTest(enabled): curr_setting
' Enable on-chip magnetometer self-test
' Dummy method

PUB MagSoftreset{}
' Perform soft-test of magnetometer
' Dummy method

PUB Reset{}
' Reset the device

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, byte_ord
' Read nr_bytes from slave device into ptr_buff
    case reg_nr                                 ' validate reg #
        $32_20..$32_27, $32_2E..$32_3D:         ' Accel regs
            byte_ord := LSBF
        $32_28..$32_2D:                         ' Accel data output regs
            reg_nr |= core#RD_MULTI
            byte_ord := LSBF
        $3C_00..$3C_0C, $3C_31, $3C_32:         ' Mag regs
            byte_ord := MSBF
        other:
            return

    cmd_pkt.byte[0] := reg_nr.byte[1]           ' slave address embedded in
    cmd_pkt.byte[1] := reg_nr.byte[0]           '   the upper byte of reg_nr
    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start{}
    i2c.write(reg_nr.byte[1] | 1)
    if (byte_ord == LSBF)                       ' accelerometer data is LSBf
        i2c.rdblock_lsbf(ptr_buff, nr_bytes, TRUE)
    elseif (byte_ord == MSBF)                   ' mag is MSBf
        i2c.rdblock_msbf(ptr_buff, nr_bytes, TRUE)
    i2c.stop{}

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Write nr_bytes from ptr_buff to slave device
    case reg_nr                                 ' validate reg #
        $32_20..$32_26, $32_2E, $32_30, $32_32..$32_34, $32_36..$32_3D:
        $3C_00..$3C_02:
        other:
            return

    cmd_pkt.byte[0] := reg_nr.byte[1]
    cmd_pkt.byte[1] := reg_nr.byte[0]
    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_lsbf(ptr_buff, nr_bytes)
    i2c.stop{}


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