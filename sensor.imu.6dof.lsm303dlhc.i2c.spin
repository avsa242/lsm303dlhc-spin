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

    XL_SLAVE_WR       = core#XL_SLAVE_ADDR
    XL_SLAVE_RD       = core#XL_SLAVE_ADDR|1
    MAG_SLAVE_WR      = core#MAG_SLAVE_ADDR
    MAG_SLAVE_RD      = core#MAG_SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 100_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

    X_AXIS              = 0
    Y_AXIS              = 1
    Z_AXIS              = 2

VAR

    long _abiasraw, _mbiasraw

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

PUB AccelDataRate(Hz): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 0 (power down), 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376
'   Any other value polls the chip and returns the current setting
    curr_rate := $00
    readReg(core#CTRL_REG1_A, 1, @curr_rate)
    case Hz
        0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376:
            Hz := lookdownz(Hz: 0, 1, 10, 25, 50, 100, 200, 400, 1620, 1344, 5376)
        OTHER:
            curr_rate := ((curr_rate >> core#FLD_ODR) & core#BITS_ODR) + 1
            return lookup(curr_rate: 0, 14{.9}, 59{.5}, 119, 238, 476, 952)

    curr_rate &= core#MASK_ODR
    curr_rate := (curr_rate | Hz) & core#CTRL_REG1_A_MASK
    writeReg(core#CTRL_REG1_A, 1, @curr_rate)

PUB AccelData(ax, ay, az) | tmp[2]
' Reads the Accelerometer output registers
    readReg(core#OUT_X_L_A, 6, @tmp)

    long[ax] := ~~tmp.word[X_AXIS] - _abiasraw[X_AXIS]
    long[ay] := ~~tmp.word[Y_AXIS] - _abiasraw[Y_AXIS]
    long[az] := ~~tmp.word[Z_AXIS] - _abiasraw[Z_AXIS]

PUB DeviceID{}: id
' Read device identification

PUB Reset{}
' Reset the device

PRI readReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
'' Read num_bytes from the slave device into the address stored in buff_addr
    case reg_nr                                                 ' Basic register validation
        $1920..$1927, $192E..$193D:                             ' Accel regs
            cmd_packet.byte[0] := XL_SLAVE_WR
        $1928..$192D:
            reg_nr |= core#RD_MULTI
        $1E00..$1E0C, $1E31, $1E32:                             ' Mag regs
            cmd_packet.byte[0] := MAG_SLAVE_WR
        OTHER:
            return

    cmd_packet.byte[1] := reg_nr & $FF
    i2c.start
    i2c.wr_block (@cmd_packet, 2)
    i2c.start
    i2c.write (reg_nr.byte[1] | 1)
    i2c.rd_block (buff_addr, nr_bytes, TRUE)
    i2c.stop

PRI writeReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg_nr                                                 'Basic register validation
        $1920..$1926, $192E, $1930, $1932..$1934, $1936..$193D:
            cmd_packet.byte[0] := XL_SLAVE_WR
        $1E00..$1E02:
            cmd_packet.byte[0] := MAG_SLAVE_WR
        OTHER:
            return

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
