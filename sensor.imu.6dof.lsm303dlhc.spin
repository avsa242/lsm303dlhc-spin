{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.imu.6dof.lsm303dlhc.spin
    Description:    Driver for the ST LSM303 6DoF IMU
        Supported variants:
            LSM303AGR
            LSM303DLHC
    Author:         Jesse Burt
    Started:        Jul 29, 2020
    Updated:        Jun 19, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.accel.common.spinh"
#include "sensor.magnetometer.common.spinh"

CON

    { default I/O configuration - these can be overridden by the parent object }
    SCL             = 28
    SDA             = 29
    I2C_FREQ        = 100_000


    XL_SLAVE_WR     = core.XL_SLAVE_ADDR
    XL_SLAVE_RD     = core.XL_SLAVE_ADDR|1
    MAG_SLAVE_WR    = core.MAG_SLAVE_ADDR
    MAG_SLAVE_RD    = core.MAG_SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core.I2C_MAX_FREQ

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
#ifdef LSM303AGR
    CAL_M_SCL       = 50
    CAL_M_DR        = 100
#else
    CAL_M_SCL       = 1_3
    CAL_M_DR        = 75
#endif
    CAL_XL_DR       = 100
    CAL_G_DR        = 0

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
    IDLE            = SLEEP


VAR

    long _accel_time_res


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef LSM303_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.lsm303dlhc"               ' hw-specific low-level const's
    time:   "time"                              ' basic timing functions


PUB null()
'This is not a top-level object


PUB start(): status
' Start using default I/O configuration
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom I/O pins and I2C bus frequency
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.TPOR)              ' wait for device startup
            if ( i2c.present(XL_SLAVE_WR) )     ' test device bus presence
                return status
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()


PUB defaults()
' Set factory defaults
    accel_scale(2)
    mag_scale(1)
    mag_data_rate(15)


PUB preset_active()
' Like defaults(), but
'   * enables output data
'   * 50Hz accelerometer sample rate
    accel_data_rate(50)
    accel_scale(2)
    mag_opmode(CONT)
    mag_scale(1)


PUB preset_click_det()
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


PUB accel_adc_res(b=-2): c | tmp1, tmp2
' Set accelerometer ADC resolution, in b
'   Valid values:
'       8:  8-bit data output, Low-power mode
'       10: 10-bit data output, Normal mode
'       12: 12-bit data output, High-resolution mode
'   Any other value polls the chip and returns the current setting
    tmp1 := readreg(core.CTRL_REG1)
    tmp2 := readreg(core.CTRL_REG4)
    case b
        8:
            tmp1 &= core.LPEN_MASK
            tmp2 &= core.HR_MASK
            tmp1 := (tmp1 | (1 << core.LPEN))
        10:
            tmp1 &= core.LPEN_MASK
            tmp2 &= core.HR_MASK
        12:
            tmp1 &= core.LPEN_MASK
            tmp2 &= core.HR_MASK
            tmp2 := (tmp2 | (1 << core.HR))
        other:
            tmp1 := (tmp1 >> core.LPEN) & 1
            tmp2 := (tmp2 >> core.HR) & 1
            tmp1 := (tmp1 << 1) | tmp2
            return lookupz(tmp1: 10, 12, 8)

    writereg(core.CTRL_REG1, tmp1)
    writereg(core.CTRL_REG4, tmp2)


PUB accel_axis_ena(m=-2): c
' Enable data output for Accelerometer - per axis
'   Valid values: 0 or 1, for each axis:
'       Bits    210
'               XYZ
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG1)
    case m
        %000..%111:
            ' reverse the position of the XYZ bits, since internally, they're
            ' ZYX (XYZ order is sensor.imu standard)
            m := (m >< 3) & core.XYZEN_BITS
        other:
            return ((c & core.XYZEN_BITS) >< 3)

    m := ((c & core.XYZEN_MASK) | m)
    writereg(core.CTRL_REG1, m)


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
    readreg(core.OUT_X_L, 6, @tmp)

    ' accel data is 12bit, left-justified in a 16bit word
    '   extend sign, then right-justify
    long[ax] := (~~tmp.word[X_AXIS] ~> 4) - _abias[X_AXIS]
    long[ay] := (~~tmp.word[Y_AXIS] ~> 4) - _abias[Y_AXIS]
    long[az] := (~~tmp.word[Z_AXIS] ~> 4) - _abias[Z_AXIS]


PUB accel_data_overrun(): f
' Flag indicating previously acquired data has been overwritten
'   Returns:
'       Bits 3210 (decimal val):
'           3 (8): X, Y, and Z-axis data overrun
'           2 (4): Z-axis data overrun
'           1 (2): Y-axis data overrun
'           0 (1): X-axis data overrun
'       Returns 0 otherwise
    f := readreg(core.STATUS_REG)
    return ((f >> core.X_OR) & core.OR_BITS)


PUB accel_data_rdy(): f
' Flag indicating accelerometer data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    f := readreg(core.STATUS_REG)
    return ( ( (f >> core.ZYXDA) & 1) == 1)


PUB accel_data_rate(r=-2): c
' Set accelerometer output data rate, in Hz
'   Valid values: 0 (power down), 1, 10, 25, *50, 100, 200, 400, 1620, 1344, 5376
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG1)
    case r
        0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376:
            _accel_time_res := (1_000000 / r)   ' calc time resolution
            r := lookdownz(r: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376) << core.ODR
        other:
            c := ((c >> core.ODR) & core.ODR_BITS)
            return lookupz(c: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376)

    r := ((c & core.ODR_MASK) | r)
    writereg(core.CTRL_REG1, r)


PUB accel_int(): c
' Read accelerometer interrupt state
'   Bit 6543210 (For each bit, 0: No interrupt, 1: Interrupt has been generated)
'       6: One or more interrupts have been generated
'       5: Z-axis high event
'       4: Z-axis low event
'       3: Y-axis high event
'       2: Y-axis low event
'       1: X-axis high event
'       0: X-axis low event
    return readreg(core.INT1_SRC)


PUB accel_int_mask(m=-2): c
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
    case m
        %000000..%111111:
            writereg(core.INT1_CFG, m)
        other:
            return readreg(core.INT1_CFG)


PUB accel_int_thresh(): t
' Get accelerometer interrupt threshold level
'   Returns: micro-g's
    t := readreg(core.INT1_THS)
    case accel_scale()
        2: t *= 16_000
        4: t *= 32_000
        8: t *= 62_000
        16: t *= 186_000                        ' scale to micro-g's


PUB accel_int_set_thresh(t) | ascl
' Set accelerometer interrupt threshold level, in micro-g's
'   Valid values: 0..16_000000 (clamped to range)
    case accel_scale()
        2: ascl := 16_000
        4: ascl := 32_000
        8: ascl := 62_000
        16: ascl := 186_000                 ' scale to reg range
    t := ((0 #> thresh <# 16_000000) / ascl)
    writereg(core.INT1_THS, t)


PUB accel_scale(s=-2): c
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, 8, 16
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG4)
    case s
        2, 4, 8, 16:
            s := lookdownz(s: 2, 4, 8, 16)
#ifdef LSM303AGR
            _ares := lookupz(s: 0_980, 1_950, 3_900, 11_720)
#else
            _ares := lookupz(s: 1_000, 2_000, 4_000, 12_000)
#endif
            s <<= core.FS
        other:
            c := (c >> core.FS) & core.FS_BITS
            return lookupz(c: 2, 4, 8, 16)

    s := ((c & core.FS_MASK) | s)
    writereg(core.CTRL_REG4, s)


PUB click_axis_ena(m=-2): c
' Enable click detection per axis, and per click type
'   Valid values:
'       Bits: 5..0
'       [5..4]: Z-axis double-click..single-click
'       [3..2]: Y-axis double-click..single-click
'       [1..0]: X-axis double-click..single-click
'   Any other value polls the chip and returns the current setting
    case m
        %000000..%111111:
            writereg(core.CLICK_CFG, m)
        other:
            return readreg(core.CLICK_CFG)


PUB clicked(): f
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    return ( ( (clickedint >> core.SCLICK) & core.CLICK_BITS) <> 0)


PUB clicked_int(): i
' Clicked interrupt status
'   Bits: 6..0
'       6: Interrupt active
'       5: Double-clicked
'       4: Single-clicked
'       3: Click sign (0: positive, 1: negative)
'       2: Z-axis clicked
'       1: Y-axis clicked
'       0: X-axis clicked
    return readreg(core.CLICK_SRC)


PUB click_int_ena(s=-2): c
' Enable click interrupts on INT1
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG3)
    case ||(s)
        0, 1:
            s := ||(s) << core.I1_CLICK
        other:
            return ((c >> core.I1_CLICK) == 1)

    s := ((c & core.I1_CLICK_MASK) | s)
    writereg(core.CTRL_REG3, s)


PUB click_latency(): t
' Get maximum elapsed interval between start of click and end of click
'   Returns: microseconds
    t := readreg(core.TIME_LATENCY)
    return (t * _accel_time_res)


PUB click_set_latency(t)
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
    t := ((0 #> t <# (_accel_time_res * 255)) / _accel_time_res)
    writereg(core.TIME_LATENCY, t)


PUB click_thresh(): t | ares
' Get threshold for recognizing a click
'   Returns: micro-g's
    ares := (accel_scale() * 1_000000) / 128    ' Resolution is current scale / 128
    t := readreg(core.CLICK_THS)
    return (t * ares)


PUB click_set_thresh(t) | ares
' Set threshold for recognizing a click, in micro-g's
'   Valid values:
'       accel_scale()   Max thresh
'       2               1_984375 (= 1.984375g)
'       4               3_968750 (= 3.968750g)
'       8               7_937500 (= 7.937500g)
'       16              15_875000 (= 15.875000g)
'   NOTE: Each LSB = (accel_scale()/128)*1M (e.g., 4g scale lsb=31250ug = 0_031250ug = 0.03125g)
    ares := (accel_scale() * 1_000000) / 128    ' Resolution is current scale / 128
    t := ((0 #> t <# (127 * ares) ) / ares)
    writereg(core.CLICK_THS, t)


PUB click_time(): c
' Get maximum elapsed interval between start of click and end of click
'   Returns: microseconds
    c := readreg(core.TIME_LIMIT)
    return (c * _accel_time_res)


PUB click_set_time(t)
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
    t := ((0 #> t <# (_accel_time_res * 127)) / _accel_time_res)
    writereg(core.TIME_LIMIT, t)


PUB dbl_click_win(): t
' Get maximum elapsed interval between two consecutive clicks
'   Returns: microseconds
    t := readreg(core.TIME_WINDOW)
    return (t * _accel_time_res)


PUB dbl_click_set_win(t)
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
    t := ((0 #> t <# (_accel_time_res * 255)) / _accel_time_res)
    writereg(core.TIME_WINDOW, t)


PUB fifo_ena(e=-2): c
' Enable FIFO memory
'   Valid values: FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG5)
    case ||(e)
        0, 1:
            e := ||(e) << core.FIFO_EN
        other:
            return (((c >> core.FIFO_EN) & 1) == 1)

    e := ((c & core.FIFO_EN_MASK) | e)
    writereg(core.CTRL_REG5, e)


PUB fifo_empty(): f
' Flag indicating FIFO is empty
'   Returns: FALSE (0): FIFO contains at least one sample, TRUE(-1): FIFO is empty
    f := readreg(core.FIFO_SRC_REG)
    return (((f >> core.EMPTY) & 1) == 1)


PUB fifo_full(): f
' Flag indicating FIFO is full
'   Returns: FALSE (0): FIFO contains less than 32 samples, TRUE(-1): FIFO contains 32 samples
    f := readreg(core.FIFO_SRC_REG)
    return (((f >> core.OVRN_FIFO) & 1) == 1)


PUB fifo_mode(m=-2): c
' Set FIFO behavior
'   Valid values:
'       BYPASS      (%00) - Bypass mode - FIFO off
'       FIFO        (%01) - FIFO mode
'       STREAM      (%10) - Stream mode
'       STREAM2FIFO (%11) - Stream-to-FIFO mode
'   Any other value polls the chip and returns the current setting
    c := readreg(core.FIFO_CTRL_REG)
    case m
        BYPASS, FIFO, STREAM, STREAM2FIFO:
            m <<= core.FM
        other:
            return ((c >> core.FM) & core.FM_BITS)

    m := ((c & core.FM_MASK) | m)
    writereg(core.FIFO_CTRL_REG, m)


PUB fifo_thresh(t=-2): c
' Set FIFO threshold thresh
'   Valid values: 1..32
'   Any other value polls the chip and returns the current setting
    c := readreg(core.FIFO_CTRL_REG)
    case t
        1..32:
            t -= 1
        other:
            return ((c & core.FTH_BITS) + 1)

    t := ((c & core.FTH_MASK) | t)
    writereg(core.FIFO_CTRL_REG, t)


PUB fifo_nr_unread(): s
' Number of unread samples stored in FIFO
'   Returns: 1..32
    s := readreg(core.FIFO_SRC_REG)
    return ((s & core.FSS_BITS) + 1)


#ifdef LSM303AGR
{ LSM303AGR }
PUB mag_bias(x, y, z) | tmp[2]
' Read Magnetometer calibration offset values
'   x, y, z: pointers to long-sized variables
    longfill(@tmp, 0, 2)
    readreg(core.OFFSET_X_REG_L_M, 6, @tmp)

    { copy bias values to destination variables, and cache them in RAM, too }
    long[x] := _mbias[X_AXIS] := ~~tmp.word[0]
    long[y] := _mbias[Y_AXIS] := ~~tmp.word[1]
    long[z] := _mbias[Z_AXIS] := ~~tmp.word[2]


PUB mag_block_data_update_ena(en): c
' Enable magnetometer output data block update
'   en:
'       TRUE (non-zero values): output registers not updated until MSB and LSB have been read
'           (ensures that both MSB and LSB are from the same sample)
'       FALSE (0): continuous update
'   Returns:
'       current setting if called with other values
    c := readreg(core.CFG_REG_C_M)
    if ( en => -1 )
        en := (c & core.MAG_BDU_MASK) | ( ((c <> 0) & 1) << core.MAG_BDU )
        writereg(core.CFG_REG_C_M, en)
    else
        return ( ((c >> core.MAG_BDU) & 1) == 1 )


PUB mag_data(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    longfill(@tmp, 0, 2)
    readreg(core.OUTX_L_REG_M, 6, @tmp)

    long[mx] := ~~tmp.word[0]
    long[my] := ~~tmp.word[1]
    long[mz] := ~~tmp.word[2]


PUB mag_data_rate(r=-2): c
' Set magnetometer output data rate
'   r:  data rate in Hz
'       10, 20, 50, 100 (default: 10)
'   Returns:
'       none, if parameter value passed is in the above list
'       current data rate, if other values are given
    c := readreg(core.CFG_REG_A_M)
    case r
        10, 20, 50, 100:
            r := (c & core.MAG_ODR_MASK) | (lookdownz(r: 10, 20, 50, 100) << core.MAG_ODR)
            writereg(core.CFG_REG_A_M, r)
        other:
            { map MAG_ODR bitfield 0, 1, 2, 3 to 10, 20, 50, 100 }
            return ( lookupz(((c >> core.MAG_ODR) & core.MAG_ODR_BITS): 10, 20, 50, 100) )


PUB mag_data_rdy(): f
' Flag indicating new magnetometer data is ready
'   Returns:
'       TRUE (-1) or FALSE (0)
    return ( (readreg(core.STATUS_REG_M) & core.DATA_READY) <> 0 )


PUB mag_dev_id(): id
' Read the sensor's device identification
'   Returns:
'       $40 on success
'       other values on failure
    return readreg(core.WHO_AM_I_M)


PUB mag_lpf_ena(en=-2): c
' Enable magnetometer output data low-pass filter
'   en:
'       TRUE (non-zero values -1 or greater): enable
'       FALSE (0): disable
'   Returns:
'       current setting if called with other values
    c := readreg(core.CFG_REG_B_M)
    if ( en => true )
        en := (c & core.LPF_MASK) | ((en <> 0) & 1)
        writereg(core.CFG_REG_B_M, en)
    else
        return ( (c & 1) == 1 )


PUB mag_opmode(m=-2): c
' Set magnetometer operating mode
'   m:
'       CONT (0)
'       SINGLE (1)
'       IDLE (2)
'   Returns:
'       none, if parameter value passed is in the above list
'       current data rate, if other values are given
    c := readreg(core.CFG_REG_A_M)
    case m
        CONT, SINGLE, IDLE:
            m := (c & core.MD_MASK) | m
            writereg(core.CFG_REG_A_M, m)
        other:
            return (c & core.MD_BITS)


PUB mag_scale(s=-2): c
' Set magnetometer full-scale range
'   LSM303AGR: N/A (device has no selectable range). Provided for API compatibility only
'   Returns:
'       full-scale range, in Gauss
    longfill(@_mres, 1_500, 3)                  ' set LSM303AGR sensitivity: 1.5mGs/LSB
    return 50                                   ' LSM303AGR mag FSR is 49.152Gs


PUB mag_set_bias(x, y, z)
' Write Magnetometer calibration offset values
'   Valid values:
    writereg(core.OFFSET_X_REG_L_M, x, 2)       ' write the new bias values
    writereg(core.OFFSET_Y_REG_L_M, y, 2)
    writereg(core.OFFSET_Z_REG_L_M, z, 2)
    longmove(@_mbias, @x, 3)                    ' copy the values just set to RAM


PUB mag_temp_comp_ena(en=-2): c
' Enable magnetometer temperature compensation
'   en:
'       TRUE (non-zero values -1 or greater): enable
'       FALSE (0): disable
'   Returns:
'       current setting when called with other values
    c := readreg(core.CFG_REG_A_M)
    if ( en => -1 )
        en := (c & core.COMP_TEMP_EN_MASK) | (((en <> 0) & 1) << core.COMP_TEMP_EN)
        writereg(core.CFG_REG_A_M, en)
    else
        return ( ((c >> core.COMP_TEMP_EN) & 1) == 1 )

#else

{ LSM303DLHC }
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
    readreg(core.OUT_X_H_M, 6, @tmp)

    long[mx] := ~~tmp.word[0] - _mbias[X_AXIS]
    long[my] := ~~tmp.word[2] - _mbias[Y_AXIS]
    long[mz] := ~~tmp.word[1] - _mbias[Z_AXIS]


PUB mag_data_rate(r=-2): c
' Set Magnetometer Output Data Rate, in Hz
'   Valid values: 0 (0.75), 1 (1.5), 3, 7 (7.5), *15, 30, 75, 220
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CRA_REG_M)
    case r
        0, 1, 3, 7, 15, 30, 75, 220:
            r := lookdownz(r: 0, 1, 3, 7, 15, 30, 75, 220) << core.DO
        other:
            c := ((c >> core.DO) & core.DO_BITS)
            return lookupz(c: 0, 1, 3, 7, 15, 30, 75, 220)

    r := ((c & core.DO_MASK) | r)
    writereg(core.CRA_REG_M, r)


PUB mag_data_rdy(): f
'   Flag indicating new magnetometer data available
'       Returns: TRUE(-1) if data available, FALSE otherwise
    f := readreg(core.SR_REG_M)
    return ((readreg(core.SR_REG_M) & core.DRDY_BITS) == 0)


PUB mag_opmode(m=-2): c
' Set magnetometer operating mode
'   Valid values:
'       CONT (0): Continuous conversion
'       SINGLE (1): Single conversion
'       SLEEP (2, 3): Power down
    case m
        CONT, SINGLE, SLEEP, 3:
            m &= core.MR_REG_M_MASK
            writereg(core.MR_REG_M, m)
        other:
            c := readreg(core.MR_REG_M)
            return (c & core.MD_BITS)


PUB mag_scale(s=-2): c
' Set full scale of Magnetometer, in Gauss
'   Valid values: *1 (1.3), 2 (1.9), 3 (2.5), 4, 5 (4.7), 6 (5.6), 8 (8.1)
'   Any other value polls the chip and returns the current setting
    case s
        1, 2, 3, 4, 5, 6, 8:
            s := lookdown(s: 1, 2, 3, 4, 5, 6, 8)
            _mres[X_AXIS] := lookup(s:  0_000909, 0_001169, 0_001492, 0_002222, 0_002500, ...
                                            0_003030, 0_004347)
            _mres[Y_AXIS] := lookup(s:  0_000909, 0_001169, 0_001492, 0_002222, 0_002500, ...
                                            0_003030, 0_004347)
            _mres[Z_AXIS] := lookup(s:  0_001020, 0_001315, 0_001666, 0_002500, 0_002816, ...
                                            0_003389, 0_004878)
            s <<= core.GN
            writereg(core.CRB_REG_M, s)
        other:
            c := readreg(core.CRB_REG_M)
            c := (c >> core.GN) & core.GN_BITS
            return lookup(c: 1, 2, 3, 4, 5, 6, 8)

#endif


PRI readreg(reg_nr, len=0, p_dest=0): v | cmd_pkt, byte_ord
' Read nr_bytes from slave device into ptr_buff
    v := 0
    case reg_nr                                 ' validate reg #
        $32_20..$32_27, $32_2E..$32_3D:         ' Accel regs
            byte_ord := LSBF
        $32_28..$32_2D:                         ' Accel data output regs
            reg_nr |= core.RD_MULTI
            byte_ord := LSBF
#ifdef LSM303AGR
        $3c_45..$3c4a, $3c_4f, $3c_60..$3c6d:
            byte_ord := LSBF
#else
        $3C_00..$3C_0C, $3C_31, $3C_32:         ' Mag regs
            byte_ord := MSBF
#endif
        other:
            return

    cmd_pkt.byte[0] := reg_nr.byte[1]           ' slave address embedded in
    cmd_pkt.byte[1] := reg_nr.byte[0]           '   the upper byte of reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start()
    i2c.write(reg_nr.byte[1] | 1)
    if (byte_ord == LSBF)                       ' accelerometer data is LSBf
        if ( len )
            i2c.rdblock_lsbf(p_dest, len, i2c.NAK)
        else
            i2c.rdblock_lsbf(@v, 1, i2c.NAK)
    elseif (byte_ord == MSBF)                   ' mag is MSBf
        if ( len )
            i2c.rdblock_msbf(p_dest, len, i2c.NAK)
        else
            i2c.rdblock_msbf(@v, 1, i2c.NAK)
    i2c.stop()


PRI writereg(reg_nr, val, len=1) | cmd_pkt, tmp
' Write nr_bytes from ptr_buff to slave device
    case reg_nr                                 ' validate reg #
        $32_20..$32_26, $32_2E, $32_30, $32_32..$32_34, $32_36..$32_3D:
#ifdef LSM303AGR
        $3c_45..$3c_4a, $3c_60..$3c_63, $3c_66:
#else
        $3C_00..$3C_02:
#endif
        other:
            return

    cmd_pkt.byte[0] := reg_nr.byte[1]
    cmd_pkt.byte[1] := reg_nr.byte[0]
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_lsbf(@val, len)
    i2c.stop()


DAT
{
Copyright 2024 Jesse Burt

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

