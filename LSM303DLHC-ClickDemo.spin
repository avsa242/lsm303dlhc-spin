{
----------------------------------------------------------------------------------------------------
    Filename:       LSM303DLHC-ClickDemo.spin
    Description:    Demo of the LSM303DLHC driver
        * click-detection functionality
    Author:         Jesse Burt
    Started:        Aug 1, 2020
    Updated:        Aug 27, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine
'#define LSM303DLHC_I2C_BC
'#pragma exportdef(LSM303DLHC_I2C_BC)

' Uncomment the two lines below if the sensor is an LSM303AGR (otherwise, an LSM303DLHC is assumed)
'#define LSM303AGR
'#pragma exportdef(LSM303AGR)


CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    accel:  "sensor.imu.6dof.lsm303dlhc" | SCL=28, SDA=29, I2C_FREQ=400_000
    time:   "time"


PUB main() | click_src, int_act, dclicked, sclicked, z_clicked, y_clicked, x_clicked

    setup()
    accel.preset_click_det()                    ' preset settings for
                                                ' click-detection

    ser.hide_cursor()                           ' hide terminal cursor

    repeat until (ser.getchar_noblock() == "q") ' press q to quit
        click_src := accel.clicked_int()
        int_act := ( (click_src >> 6) & 1)
        dclicked := ( (click_src >> 5) & 1)
        sclicked := ( (click_src >> 4) & 1)
        z_clicked := ( (click_src >> 2) & 1)
        y_clicked := ( (click_src >> 1) & 1)
        x_clicked := (click_src & 1)
        ser.pos_xy(0, 3)
        ser.printf(@"Click interrupt: %s\n\r", yesno(int_act) )
        ser.printf(@"Double-clicked:  %s\n\r", yesno(dclicked) )
        ser.printf(@"Single-clicked:  %s\n\r", yesno(sclicked) )
        ser.printf(@"Z-axis clicked:  %s\n\r", yesno(z_clicked) )
        ser.printf(@"Y-axis clicked:  %s\n\r", yesno(y_clicked) )
        ser.printf(@"X-axis clicked:  %s\n\r", yesno(x_clicked) )

    ser.show_cursor()                           ' restore terminal cursor
    repeat


PRI yesno(val): resp
' Return pointer to string "Yes" or "No" depending on value called with
    ifnot ( val )
        return @"No "
    else
        return @"Yes"


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( accel.start() )
        ser.strln(@"LSM303 driver started (I2C)")
    else
        ser.strln(@"LSM303 driver failed to start - halting")
        repeat


DAT
{
Copyright 2025 Jesse Burt

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

