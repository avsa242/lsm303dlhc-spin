{
    --------------------------------------------
    Filename: core.con.lsm303dlhc.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2020
    Started Jul 29, 2020
    Updated Jul 29, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ        = 400_000
    XL_SLAVE_ADDR       = $19 << 1
    MAG_SLAVE_ADDR      = $1E << 1

    RD_MULTI            = 1 << 7

' Register definitions
    CTRL_REG1_A         = $1920
    CTRL_REG1_A_MASK    = $FF
        FLD_ODR         = 4
        FLD_LPEN        = 3
        FLD_ZEN         = 2
        FLD_YEN         = 1
        FLD_XEN         = 0
        FLD_XYZEN       = 0
        BITS_ODR        = %1111
        BITS_XYZEN      = %111
        MASK_ODR        = CTRL_REG1_A_MASK ^ (BITS_ODR << FLD_ODR)
        MASK_LPEN       = CTRL_REG1_A_MASK ^ (1 << FLD_LPEN)
        MASK_ZEN        = CTRL_REG1_A_MASK ^ (1 << FLD_ZEN)
        MASK_YEN        = CTRL_REG1_A_MASK ^ (1 << FLD_YEN)
        MASK_XEN        = CTRL_REG1_A_MASK ^ (1 << FLD_XEN)
        MASK_XYZEN      = CTRL_REG1_A_MASK ^ (BITS_XYZEN << FLD_XYZEN)

    CTRL_REG2_A         = $1921
    CTRL_REG3_A         = $1922
    CTRL_REG4_A         = $1923
    CTRL_REG5_A         = $1924
    CTRL_REG6_A         = $1925
    REFERENCE_A         = $1926
    STATUS_REG_A        = $1927
    OUT_X_L_A           = $1928
    OUT_X_H_A           = $1929
    OUT_Y_L_A           = $192A
    OUT_Y_H_A           = $192B
    OUT_Z_L_A           = $192C
    OUT_Z_H_A           = $192D
    FIFO_CTRL_REG_A     = $192E
    FIFO_SRC_REG_A      = $192F
    INT1_CFG_A          = $1930
    INT1_SRC_A          = $1931
    INT1_THS_A          = $1932
    INT1_DURATION_A     = $1933
    INT2_CFG_A          = $1934
    INT2_SRC_A          = $1935
    INT2_THS_A          = $1936
    INT2_DURATION_A     = $1937
    CLICK_CFG_A         = $1938
    CLICK_SRC_A         = $1939
    CLICK_THS_A         = $193A
    TIME_LIMIT_A        = $193B
    TIME_LATENCY_A      = $193C
    TIME_WINDOW_A       = $193D

    CRA_REG_M           = $1E00
    CRB_REG_M           = $1E01
    MR_REG_M            = $1E02
    OUT_X_H_M           = $1903
    OUT_X_L_M           = $1904
    OUT_Y_H_M           = $1905
    OUT_Y_L_M           = $1906
    OUT_Z_H_M           = $1907
    OUT_Z_L_M           = $1908
    SR_REG_M            = $1909
    IRA_REG_M           = $190A
    IRB_REG_M           = $190B
    IRC_REG_M           = $190C
    TEMP_OUT_H_M        = $1931
    TEMP_OUT_H_L        = $1932



#ifndef __propeller2__
PUB Null
'' This is not a top-level object
#endif
