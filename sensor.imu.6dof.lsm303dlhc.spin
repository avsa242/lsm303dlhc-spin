{
    --------------------------------------------
    Filename: sensor.imu.6dof.lsm303dlhc.spin
    Author: Jesse Burt
    Description: Driver for the ST LSM303DLHC 6DoF IMU
    Copyright (c) 2022
    Started Jul 29, 2020
    Updated Oct 2, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.accel.common.spinh"
#include "sensor.magnetometer.common.spinh"

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

    long _accel_time_res

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef LSM303DLHC_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.lsm303dlhc"                 ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB null{}
'This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    status := startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
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

PUB stop{}
' Stop the driver
    i2c.deinit{}

PUB defaults{}
' Set factory defaults
    accel_scale(2)
    mag_scale(1)
    mag_data_rate(15)

PUB preset_active{}
' Like defaults(), but
'   * enables output data
'   * 50Hz accelerometer sample rate
    accel_data_rate(50)
    accel_scale(2)
    mag_opmode(CONT)
    mag_scale(1)

PUB preset_click_det{}
' Presets for click-detection
    accel_adc_res(12)
    accel_scale(4)
    accel_data_rate(400)
    accel_axis_ena(%111)
    click_set_thresh(1_187500)
    click_axis_ena(%11_00_00)
    click_set_time(127_000)
    dbl_click_set_win(637_500)
    click_set_latency(150_000)
    click_int_ena(TRUE)

PUB accel_adc_res(bits): curr_res | tmp1, tmp2
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

PUB accel_axis_ena(mask): curr_mask
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

PUB accel_bias(x, y, z)
' Read accelerometer calibration offset values
'   x, y, z: pointers to copy offsets to
    long[x] := _abias[X_AXIS]
    long[y] := _abias[Y_AXIS]
    long[z] := _abias[Z_AXIS]

PUB accel_set_bias(x, y, z)
' Write accelerometer calibration offset values
'   Valid values:
'       -1024..1023 (clamped to range)
    _abias[X_AXIS] := (-1024 #> x <# 1023)
    _abias[Y_AXIS] := (-1024 #> y <# 1023)
    _abias[Z_AXIS] := (-1024 #> z <# 1023)

PUB accel_data(ax, ay, az) | tmp[2]
' Read the Accelerometer output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_L, 6, @tmp)

    ' accel data is 12bit, left-justified in a 16bit word
    '   extend sign, then right-justify
    long[ax] := (~~tmp.word[X_AXIS] ~> 4) - _abias[X_AXIS]
    long[ay] := (~~tmp.word[Y_AXIS] ~> 4) - _abias[Y_AXIS]
    long[az] := (~~tmp.word[Z_AXIS] ~> 4) - _abias[Z_AXIS]

PUB accel_data_overrun{}: flag
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

PUB accel_data_rdy{}: flag
' Flag indicating accelerometer data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#STATUS_REG, 1, @flag)
    return (((flag >> core#ZYXDA) & 1) == 1)

PUB accel_data_rate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 0 (power down), 1, 10, 25, *50, 100, 200, 400, 1620, 1344, 5376
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376:
            _accel_time_res := (1_000000 / rate)' calc time resolution
            rate := lookdownz(rate: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376) << core#ODR
        other:
            curr_rate := ((curr_rate >> core#ODR) & core#ODR_BITS)
            return lookupz(curr_rate: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376)

    rate := ((curr_rate & core#ODR_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)

PUB accel_int{}: curr_state
' Read accelerometer interrupt state
'   Bit 6543210 (For each bit, 0: No interrupt, 1: Interrupt has been generated)
'       6: One or more interrupts have been generated
'       5: Z-axis high event
'       4: Z-axis low event
'       3: Y-axis high event
'       2: Y-axis low event
'       1: X-axis high event
'       0: X-axis low event
    curr_state := 0
    readreg(core#INT1_SRC, 1, @curr_state)

PUB accel_int_mask(mask): curr_mask
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

PUB accel_int_thresh{}: thresh
' Get accelerometer interrupt threshold level
'   Returns: micro-g's
    thresh := 0
    readreg(core#INT1_THS, 1, @thresh)
    case accel_scale(-2)
        2: thresh *= 16_000
        4: thresh *= 32_000
        8: thresh *= 62_000
        16: thresh *= 186_000                   ' scale to micro-g's

PUB accel_int_set_thresh(thresh) | ascl
' Set accelerometer interrupt threshold level, in micro-g's
'   Valid values: 0..16_000000 (clamped to range)
    case accel_scale(-2)
        2: ascl := 16_000
        4: ascl := 32_000
        8: ascl := 62_000
        16: ascl := 186_000                 ' scale to reg range
    thresh := ((0 #> thresh <# 16_000000) / ascl)
    writereg(core#INT1_THS, 1, @thresh)

PUB accel_scale(scale): curr_scl
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

PUB click_axis_ena(mask): curr_mask
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

PUB clicked{}: flag
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    return (((clickedint >> core#SCLICK) & core#CLICK_BITS) <> 0)

PUB clicked_int{}: int_src
' Clicked interrupt status
'   Bits: 6..0
'       6: Interrupt active
'       5: Double-clicked
'       4: Single-clicked
'       3: Click sign (0: positive, 1: negative)
'       2: Z-axis clicked
'       1: Y-axis clicked
'       0: X-axis clicked
    int_src := 0
    readreg(core#CLICK_SRC, 1, @int_src)

PUB click_int_ena(state): curr_state
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

PUB click_latency{}: ltime
' Get maximum elapsed interval between start of click and end of click
'   Returns: microseconds
    ltime := 0
    readreg(core#TIME_LATENCY, 1, @ltime)
    return (ltime * _accel_time_res)

PUB click_set_latency(ltime)
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'       accel_data_rate()   Min time (uS/step size) Max time (uS)   (equiv. range in mS)
'       1                   1_000_000               255_000_000     1,000 .. 255,000
'       10                  100_000                 25_500_000        100 .. 25,500
'       25                  40_000                  10_200_000       40.0 .. 10,200
'       50                  20_000                  5_100_000        20.0 .. 5,100
'       100                 10_000                  2_550_000        10.0 .. 2,550
'       200                 5_000                   1_275_000         5.0 .. 1,275
'       400                 2_500                   637_500           2.5 .. 637.5
'       1344                744                     189_732         0.744 .. 189.732
'       1600                625                     159_375         0.625 .. 159.375
'   NOTE: Minimum unit is dependent on the current accel_data_rate()
'   NOTE: ST application note example uses accel_data_rate(400)
    ltime := ((0 #> ltime <# (_accel_time_res * 255)) / _accel_time_res)
    writereg(core#TIME_LATENCY, 1, @ltime)

PUB click_thresh{}: thresh | ares
' Get threshold for recognizing a click
'   Returns: micro-g's
    ares := (accel_scale(-2) * 1_000000) / 128   ' Resolution is current scale / 128
    thresh := 0
    readreg(core#CLICK_THS, 1, @thresh)
    return (thresh * ares)

PUB click_set_thresh(thresh) | ares
' Set threshold for recognizing a click, in micro-g's
'   Valid values:
'       accel_scale()   Max thresh
'       2               1_984375 (= 1.984375g)
'       4               3_968750 (= 3.968750g)
'       8               7_937500 (= 7.937500g)
'       16              15_875000 (= 15.875000g)
'   NOTE: Each LSB = (accel_scale()/128)*1M (e.g., 4g scale lsb=31250ug = 0_031250ug = 0.03125g)
    ares := (accel_scale(-2) * 1_000000) / 128   ' Resolution is current scale / 128
    thresh := ((0 #> thresh <# (127 * ares)) / ares)
    writereg(core#CLICK_THS, 1, @thresh)

PUB click_time{}: ctime | time_res
' Get maximum elapsed interval between start of click and end of click
'   Returns: microseconds
    ctime := 0
    readreg(core#TIME_LIMIT, 1, @ctime)
    return (ctime * _accel_time_res)

PUB click_set_time(ctime)
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'       accel_data_rate()   Min time (uS/step size) Max time (uS)   (equiv. mS)
'       1                   1_000_000               127_000_000     127,000
'       10                  100_000                 12_700_000       12,700
'       25                  40_000                  5_080_000         5,080
'       50                  20_000                  2_540_000         2,540
'       100                 10_000                  1_270_000         1,127
'       200                 5_000                   635_000             635
'       400                 2_500                   317_500             317
'       1344                744                     94_494               94
'       1600                625                     79_375               79
'   NOTE: Minimum unit is dependent on the current accel_data_rate()
'   NOTE: ST application note example uses accel_data_rate(400)
    ctime := ((0 #> ctime <# (_accel_time_res * 127)) / _accel_time_res)
    writereg(core#TIME_LIMIT, 1, @ctime)

PUB dbl_click_win{}: dctime
' Get maximum elapsed interval between two consecutive clicks
'   Returns: microseconds
    dctime := 0
    readreg(core#TIME_WINDOW, 1, @dctime)
    return (dctime * _accel_time_res)

PUB dbl_click_set_win(dctime)
' Set maximum elapsed interval between two consecutive clicks, in uSec
'   Valid values:
'       accel_data_rate()   Min time (uS/step size) Max time (uS)   (equiv. range in mS)
'       1                   1_000_000               255_000_000     1,000 .. 255,000
'       10                  100_000                 25_500_000        100 .. 25,500
'       25                  40_000                  10_200_000       40.0 .. 10,200
'       50                  20_000                  5_100_000        20.0 .. 5,100
'       100                 10_000                  2_550_000        10.0 .. 2,550
'       200                 5_000                   1_275_000         5.0 .. 1,275
'       400                 2_500                   637_500           2.5 .. 637.5
'       1344                744                     189_732         0.744 .. 189.732
'       1600                625                     159_375         0.625 .. 159.375
'   Any other value polls the chip and returns the current setting
'   NOTE: Minimum unit is dependent on the current accel_data_rate()
'   NOTE: ST application note example uses accel_data_rate(400)
    dctime := ((0 #> dctime <# (_accel_time_res * 255)) / _accel_time_res)
    writereg(core#TIME_WINDOW, 1, @dctime)

PUB fifo_ena(state): curr_state
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

PUB fifo_empty{}: flag
' Flag indicating FIFO is empty
'   Returns: FALSE (0): FIFO contains at least one sample, TRUE(-1): FIFO is empty
    flag := 0
    readreg(core#FIFO_SRC_REG, 1, @flag)
    return (((flag >> core#EMPTY) & 1) == 1)

PUB fifo_full{}: flag
' Flag indicating FIFO is full
'   Returns: FALSE (0): FIFO contains less than 32 samples, TRUE(-1): FIFO contains 32 samples
    flag := 0
    readreg(core#FIFO_SRC_REG, 1, @flag)
    return (((flag >> core#OVRN_FIFO) & 1) == 1)

PUB fifo_mode(mode): curr_mode
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

PUB fifo_thresh(thresh): curr_thr
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

PUB fifo_nr_unread{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 1..32
    nr_samples := 0
    readreg(core#FIFO_SRC_REG, 1, @nr_samples)
    return ((nr_samples & core#FSS_BITS) + 1)

PUB mag_bias(x, y, z)
' Read Magnetometer calibration offset values
    long[x] := _mbias[X_AXIS]
    long[y] := _mbias[Y_AXIS]
    long[z] := _mbias[Z_AXIS]

PUB mag_set_bias(x, y, z)
' Write Magnetometer calibration offset values
'   Valid values:
'       -2048..2047 (clamped to range)
    _mbias[X_AXIS] := -2048 #> x <# 2047
    _mbias[Y_AXIS] := -2048 #> y <# 2047
    _mbias[Z_AXIS] := -2048 #> z <# 2047

PUB mag_data(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_H_M, 6, @tmp)
    long[mx] := ~~tmp.word[0] - _mbias[X_AXIS]
    long[my] := ~~tmp.word[2] - _mbias[Y_AXIS]
    long[mz] := ~~tmp.word[1] - _mbias[Z_AXIS]

PUB mag_data_rate(rate): curr_rate
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

PUB mag_data_rdy{}: flag
'   Flag indicating new magnetometer data available
'       Returns: TRUE(-1) if data available, FALSE otherwise
    flag := 0
    readreg(core#SR_REG_M, 1, @flag)
    return ((flag & core#DRDY_BITS) == 0)

PUB mag_opmode(mode): curr_mode
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

PUB mag_scale(scale): curr_scl
' Set full scale of Magnetometer, in Gauss
'   Valid values: *1 (1.3), 2 (1.9), 3 (2.5), 4, 5 (4.7), 6 (5.6), 8 (8.1)
'   Any other value polls the chip and returns the current setting
    case scale
        1, 2, 3, 4, 5, 6, 8:
            scale := lookdown(scale: 1, 2, 3, 4, 5, 6, 8)
            _mres[X_AXIS] := lookup(scale: 0_000909, 0_001169, 0_001492, 0_002222, {
}           0_002500, 0_003030, 0_004347)
            _mres[Y_AXIS] := lookup(scale: 0_000909, 0_001169, 0_001492, 0_002222, {
}           0_002500, 0_003030, 0_004347)
            _mres[Z_AXIS] := lookup(scale: 0_001020, 0_001315, 0_001666, 0_002500, {
}           0_002816, 0_003389, 0_004878)
            scale <<= core#GN
            writereg(core#CRB_REG_M, 1, @scale)
        other:
            curr_scl := 0
            readreg(core#CRB_REG_M, 1, @curr_scl)
            curr_scl := (curr_scl >> core#GN) & core#GN_BITS
            return lookup(curr_scl: 1, 2, 3, 4, 5, 6, 8)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, byte_ord
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

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
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
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

