{
----------------------------------------------------------------------------------------------------
    Filename:       core.con.lsm303dlhc.spin
    Description:    LSM303-specific low-level constants
    Author:         Jesse Burt
    Started:        Jul 29, 2020
    Updated:        Jun 19, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}


CON

    I2C_MAX_FREQ                = 400_000
    XL_SLAVE_ADDR               = $19 << 1
    MAG_SLAVE_ADDR              = $1E << 1

    RD_MULTI                    = 1 << 7

    TPOR                        = 1_000         ' uSec

' Register definitions
    CTRL_REG1                   = $3220
    CTRL_REG1_MASK              = $FF
        ODR                     = 4
        LPEN                    = 3
        ZEN                     = 2
        YEN                     = 1
        XEN                     = 0
        XYZEN                   = 0
        ODR_BITS                = %1111
        XYZEN_BITS              = %111
        ODR_MASK                = (ODR_BITS << ODR) ^ CTRL_REG1_MASK
        LPEN_MASK               = (1 << LPEN) ^ CTRL_REG1_MASK
        ZEN_MASK                = (1 << ZEN) ^ CTRL_REG1_MASK
        YEN_MASK                = (1 << YEN) ^ CTRL_REG1_MASK
        XEN_MASK                = (1 << XEN) ^ CTRL_REG1_MASK
        XYZEN_MASK              = (XYZEN_BITS << XYZEN) ^ CTRL_REG1_MASK

    CTRL_REG2                   = $3221

    CTRL_REG3                   = $3222
    CTRL_REG3_MASK              = $FE
        I1_CLICK                = 7
        I1_IA1                  = 6
        I1_IA2                  = 5
        I1_ZYXDA                = 4
        I1_321DA                = 3
        I1_WTM                  = 2
        I1_OVERRUN              = 1
        I1_CLICK_MASK           = (1 << I1_CLICK) ^ CTRL_REG3_MASK
        I1_IA1_MASK             = (1 << I1_IA1) ^ CTRL_REG3_MASK
        I1_IA2_MASK             = (1 << I1_IA2) ^ CTRL_REG3_MASK
        I1_ZYXDA_MASK           = (1 << I1_ZYXDA) ^ CTRL_REG3_MASK
        I1_321DA_MASK           = (1 << I1_321DA) ^ CTRL_REG3_MASK
        I1_WTM_MASK             = (1 << I1_WTM) ^ CTRL_REG3_MASK
        I1_OVERRUN_MASK         = (1 << I1_OVERRUN) ^ CTRL_REG3_MASK

    CTRL_REG4                   = $3223
    CTRL_REG4_MASK              = $F8
        BDU                     = 7
        BLE                     = 6
        FS                      = 4
        HR                      = 3
'        SIM                    = 0
        FS_BITS                 = %11
        BDU_MASK                = (1 << BDU) ^ CTRL_REG4_MASK
        BLE_MASK                = (1 << BLE) ^ CTRL_REG4_MASK
        FS_MASK                 = (FS_BITS << FS) ^ CTRL_REG4_MASK
        HR_MASK                 = (1 << HR) ^ CTRL_REG4_MASK
'        SIM                    = CTRL_REG4_MASK ^ (1 << SIM)

    CTRL_REG5                   = $3224
    CTRL_REG5_MASK              = $CF
        BOOT                    = 7
        FIFO_EN                 = 6
        LIR_INT1                = 3
        D4D_INT1                = 2
        LIR_INT2                = 1
        D4D_INT2                = 0
        BOOT_MASK               = (1 << BOOT) ^ CTRL_REG5_MASK
        FIFO_EN_MASK            = (1 << FIFO_EN) ^ CTRL_REG5_MASK
        LIR_INT1_MASK           = (1 << LIR_INT1) ^ CTRL_REG5_MASK
        D4D_INT1_MASK           = (1 << D4D_INT1) ^ CTRL_REG5_MASK
        LIR_INT2_MASK           = (1 << LIR_INT2) ^ CTRL_REG5_MASK
        D4D_INT2_MASK           = (1 << D4D_INT2) ^ CTRL_REG5_MASK

    CTRL_REG6                   = $3225

    REFERENCE                   = $3226
    DATACAPTURE_A               = $3226         ' LSM303AGR

    STATUS_REG                  = $3227
        ZYXOR                   = 7
        Z_OR                    = 6
        Y_OR                    = 5
        X_OR                    = 4
        ZYXDA                   = 3
        ZDA                     = 2
        YDA                     = 1
        XDA                     = 0
        OR_BITS                 = %1111
        DA_BITS                 = %1111

    OUT_X_L                     = $3228
    OUT_X_H                     = $3229
    OUT_Y_L                     = $322A
    OUT_Y_H                     = $322B
    OUT_Z_L                     = $322C
    OUT_Z_H                     = $322D

    FIFO_CTRL_REG               = $322E
    FIFO_CTRL_REG_MASK          = $FF
        FM                      = 6
        TR                      = 5
        FTH                     = 0
        FM_BITS                 = %11
        FTH_BITS                = %11111
        FM_MASK                 = (FM_BITS << FM) ^ FIFO_CTRL_REG_MASK
        TR_MASK                 = (1 << TR) ^ FIFO_CTRL_REG_MASK
        FTH_MASK                = (FTH_BITS << FTH) ^ FIFO_CTRL_REG_MASK

    FIFO_SRC_REG                = $322F
    FIFO_SRC_REG_MASK           = $FF
        WTM                     = 7
        OVRN_FIFO               = 6
        EMPTY                   = 5
        FSS                     = 0
        FSS_BITS                = %11111
        WTM_MASK                = (1 << WTM) ^ FIFO_SRC_REG_MASK
        OVRN_FIFO_MASK          = (1 << OVRN_FIFO) ^ FIFO_SRC_REG_MASK
        EMPTY_MASK              = (1 << EMPTY) ^ FIFO_SRC_REG_MASK
        FSS_MASK                = (FSS_BITS << FSS) ^ FIFO_SRC_REG_MASK

    INT1_CFG                    = $3230
    INT1_SRC                    = $3231
    INT1_THS                    = $3232
    INT1_DURATION               = $3233
    INT2_CFG                    = $3234
    INT2_SRC                    = $3235
    INT2_THS                    = $3236
    INT2_DURATION               = $3237

    CLICK_CFG                   = $3238

    CLICK_SRC                   = $3239
    CLICK_SRC_MASK              = $7F
        CLICK_IA                = 6
        DCLICK                  = 5
        SCLICK                  = 4
        SIGN                    = 3
        Z                       = 2
        Y                       = 1
        X                       = 0
        CLICK_BITS              = %11

    CLICK_THS                   = $323A

    TIME_LIMIT                  = $323B

    TIME_LATENCY                = $323C

    TIME_WINDOW                 = $323D

#ifdef LSM303AGR
    ACT_THS_A                   = $323e         ' LSM303AGR
    ACT_DUR_A                   = $323f         '

    { LSM303AGR magnetometer }
    OFFSET_X_REG_L_M            = $3c45
    OFFSET_X_REG_H_M            = $3c46
    OFFSET_Y_REG_L_M            = $3c47
    OFFSET_Y_REG_H_M            = $3c48
    OFFSET_Z_REG_L_M            = $3c49
    OFFSET_Z_REG_H_M            = $3c4a

    WHO_AM_I_M                  = $3c4f
        DEVID_RESP_M            = $40

    CFG_REG_A_M                 = $3c60
    CFG_REG_A_M_MASK            = $ff
        COMP_TEMP_EN            = 7
        COMP_TEMP_EN_MASK       = (1 << COMP_TEMP_EN) ^ CFG_REG_A_M_MASK
        REBOOT_M                = 6
        REBOOT_M_MASK           = (1 << REBOOT_M) ^ CFG_REG_A_M_MASK
        SOFT_RST                = 5
        SOFT_RST_MASK           = (1 << SOFT_RST) ^ CFG_REG_A_M_MASK
        LP                      = 4
        LP_MASK                 = (1 << LP) ^ CFG_REG_A_M_MASK
        MAG_ODR                 = 2
        MAG_ODR_BITS            = %11
        MAG_ODR_MASK            = (MAG_ODR_BITS << MAG_ODR) ^ CFG_REG_A_M_MASK
        MD                      = 0
        MD_BITS                 = %11
        MD_MASK                 = (MD_BITS << MD) ^ CFG_REG_A_M_MASK


    CFG_REG_B_M                 = $3c61
    CFG_REG_B_M_MASK            = $1f
        OFF_CANC_ONE_SHOT       = 4
        OFF_CANC_ONE_SHOT_MASK  = (1 << OFF_CANC_ONE_SHOT) ^ CFG_REG_B_M_MASK
        INT_ON_DATAOFF          = 3
        INT_ON_DATAOFF_MASK     = (1 << INT_ON_DATAOFF) ^ CFG_REG_B_M_MASK
        SET_FREQ                = 2
        SET_FREQ_MASK           = (1 << SET_FREQ) ^ CFG_REG_B_M_MASK
        OFF_CANC                = 1
        OFF_CANC_MASK           = (1 << OFF_CANC) ^ CFG_REG_B_M_MASK
        LPF                     = 0
        LPF_MASK                = (1 << LPF) ^ CFG_REG_B_M_MASK

    CFG_REG_C_M                 = $3c62
    CFG_REG_C_M_MASK            = $7b
        INT_MAG_PIN             = 6
        INT_MAG_PIN_MASK        = (1 << INT_MAG_PIN) ^ CFG_REG_C_M_MASK
        I2C_DIS                 = 5
        I2C_DIS_MASK            = (1 << I2C_DIS) ^ CFG_REG_C_M_MASK
        MAG_BDU                 = 4
        MAG_BDU_MASK            = (1 << MAG_BDU) ^ CFG_REG_C_M_MASK
        MAG_BLE                 = 3
        MAG_BLE_MASK            = (1 << MAG_BLE) ^ CFG_REG_C_M_MASK
        SELF_TEST               = 1
        SELF_TEST_MASK          = (1 << SELF_TEST) ^ CFG_REG_C_M_MASK
        INT_MAG                 = 0
        INT_MAG_MASK            = (1 << INT_MAG) ^ CFG_REG_C_M_MASK

    INT_CTRL_REG_M              = $3c63
    INT_CTRL_REG_M_MASK         = $e7
        XIEN                    = 7
        XIEN_MASK               = (1 << XIEN) ^ INT_CTRL_REG_M_MASK
        YIEN                    = 6
        YIEN_MASK               = (1 << YIEN) ^ INT_CTRL_REG_M_MASK
        ZIEN                    = 5
        ZIEN_MASK               = (1 << ZIEN) ^ INT_CTRL_REG_M_MASK
        IEA                     = 2
        IEA_MASK                = (1 << IEA) ^ INT_CTRL_REG_M_MASK
        IEL                     = 1
        IEL_MASK                = (1 << IEL) ^ INT_CTRL_REG_M_MASK
        IEN                     = 0
        IEN_MASK                = (1 << IEN) ^ INT_CTRL_REG_M_MASK

    INT_SOURCE_REG_M            = $3c64

    INT_THS_L_REG_M             = $3c65
    INT_THS_M_REG_M             = $3c66

    STATUS_REG_M                = $3c67
        ZYX_OR                  = 7
        Z_OR                    = 6
        Y_OR                    = 5
        X_OR                    = 4
        ZYXDA                   = 3
        DATA_READY              = (1 << ZYXDA)
        ZDA                     = 2
        YDA                     = 1
        XDA                     = 0

    OUTX_L_REG_M                = $3c68
    OUTX_H_REG_M                = $3c69
    OUTY_L_REG_M                = $3c6a
    OUTY_H_REG_M                = $3c6b
    OUTZ_L_REG_M                = $3c6c
    OUTZ_H_REG_M                = $3c6d
#else
    { LSM303DLHC magnetometer}
    CRA_REG_M                   = $3C00
    CRA_REG_M_MASK              = $9C
        TEMP_EN                 = 7
        DO                      = 2
        DO_BITS                 = %111
        TEMP_EN_MASK            = (1 << TEMP_EN) ^ CRA_REG_M_MASK
        DO_MASK                 = (DO_BITS << DO) ^ CRA_REG_M_MASK

    CRB_REG_M                   = $3C01
    CRB_REG_M_MASK              = $E0
        GN                      = 5
        GN_BITS                 = %111

    MR_REG_M                    = $3C02
    MR_REG_M_MASK               = $03
        MD                      = 0
        MD_BITS                 = %11

    OUT_X_H_M                   = $3C03
    OUT_X_L_M                   = $3C04
    OUT_Y_H_M                   = $3C05
    OUT_Y_L_M                   = $3C06
    OUT_Z_H_M                   = $3C07
    OUT_Z_L_M                   = $3C08

    SR_REG_M                    = $3C09
        LOCK                    = 1
        DRDY                    = 0
        LOCK_BITS               = 1
        DRDY_BITS               = 1

    IRA_REG_M                   = $3C0A
    IRB_REG_M                   = $3C0B
    IRC_REG_M                   = $3C0C
    TEMP_OUT_H_M                = $3C31
    TEMP_OUT_H_L                = $3C32
#endif


PUB null()
' This is not a top-level object


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

