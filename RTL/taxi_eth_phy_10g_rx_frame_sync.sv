// // SPDX-License-Identifier: CERN-OHL-S-2.0
// /*

// Copyright (c) 2018-2025 FPGA Ninja, LLC

// Authors:
// - Alex Forencich

// */

// `resetall
// `timescale 1ns / 1ps
// `default_nettype none

// /*
//  * 10G Ethernet PHY frame sync
//  */
// module taxi_eth_phy_10g_rx_frame_sync #
// (
//     parameter HDR_W = 2,
//     parameter BITSLIP_HIGH_CYCLES = 1,
//     parameter BITSLIP_LOW_CYCLES = 7
// )
// (
//     input  wire logic              clk,
//     input  wire logic              rst,

//     /*
//      * SERDES interface
//      */
//     input  wire logic [HDR_W-1:0]  serdes_rx_hdr,
//     input  wire logic              serdes_rx_hdr_valid,
//     output wire logic              serdes_rx_bitslip,

//     /*
//      * Status
//      */
//     output wire logic              rx_block_lock
// );

// localparam BITSLIP_MAX_CYCLES = BITSLIP_HIGH_CYCLES > BITSLIP_LOW_CYCLES ? BITSLIP_HIGH_CYCLES : BITSLIP_LOW_CYCLES;
// localparam BITSLIP_COUNT_W = $clog2(BITSLIP_MAX_CYCLES);

// // check configuration
// if (HDR_W != 2)
//     $fatal(0, "Error: HDR_W must be 2");

// localparam [1:0]
//     SYNC_DATA = 2'b10,
//     SYNC_CTRL = 2'b01;

// logic [5:0] sh_count_reg = 6'd0, sh_count_next;
// logic [3:0] sh_invalid_count_reg = 4'd0, sh_invalid_count_next;
// logic [BITSLIP_COUNT_W-1:0] bitslip_count_reg = '0, bitslip_count_next;

// logic serdes_rx_bitslip_reg = 1'b0, serdes_rx_bitslip_next;

// logic rx_block_lock_reg = 1'b0, rx_block_lock_next;

// assign serdes_rx_bitslip = serdes_rx_bitslip_reg;
// assign rx_block_lock = rx_block_lock_reg;

// always_comb begin
//     sh_count_next = sh_count_reg;
//     sh_invalid_count_next = sh_invalid_count_reg;
//     bitslip_count_next = bitslip_count_reg;

//     serdes_rx_bitslip_next = serdes_rx_bitslip_reg;

//     rx_block_lock_next = rx_block_lock_reg;

//     if (bitslip_count_reg != 0) begin
//         bitslip_count_next = bitslip_count_reg-1;
//     end else if (serdes_rx_bitslip_reg) begin
//         serdes_rx_bitslip_next = 1'b0;
//         bitslip_count_next = BITSLIP_COUNT_W'(BITSLIP_LOW_CYCLES);
//     end else if (!serdes_rx_hdr_valid) begin
//         // wait for header
//     end else if (serdes_rx_hdr == SYNC_CTRL || serdes_rx_hdr == SYNC_DATA) begin
//         // valid header
//         sh_count_next = sh_count_reg + 1;
//         if (&sh_count_reg) begin
//             // valid count overflow, reset
//             sh_count_next = '0;
//             sh_invalid_count_next = '0;
//             if (sh_invalid_count_reg == 0) begin
//                 rx_block_lock_next = 1'b1;
//             end
//         end
//     end else begin
//         // invalid header
//         sh_count_next = sh_count_reg + 1;
//         sh_invalid_count_next = sh_invalid_count_reg + 1;
//         if (!rx_block_lock_reg || &sh_invalid_count_reg) begin
//             // invalid count overflow, lost block lock
//             sh_count_next = '0;
//             sh_invalid_count_next = '0;
//             rx_block_lock_next = 1'b0;

//             // slip one bit
//             serdes_rx_bitslip_next = 1'b1;
//             bitslip_count_next = BITSLIP_COUNT_W'(BITSLIP_HIGH_CYCLES);
//         end else if (&sh_count_reg) begin
//             // valid count overflow, reset
//             sh_count_next = '0;
//             sh_invalid_count_next = '0;
//         end
//     end
// end

// always_ff @(posedge clk) begin
//     sh_count_reg <= sh_count_next;
//     sh_invalid_count_reg <= sh_invalid_count_next;
//     bitslip_count_reg <= bitslip_count_next;
//     serdes_rx_bitslip_reg <= serdes_rx_bitslip_next;
//     rx_block_lock_reg <= rx_block_lock_next;

//     if (rst) begin
//         sh_count_reg <= '0;
//         sh_invalid_count_reg <= '0;
//         bitslip_count_reg <= '0;
//         serdes_rx_bitslip_reg <= 1'b0;
//         rx_block_lock_reg <= 1'b0;
//     end
// end

// endmodule

// `resetall


// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY RX frame sync
 */
module taxi_eth_phy_10g_rx_frame_sync #
(
    parameter HDR_W = 2,
    parameter BITSLIP_HIGH_CYCLES = 1,
    parameter BITSLIP_LOW_CYCLES = 7
)
(
    input  wire logic             clk,
    input  wire logic             rst,

    /*
     * SERDES interface
     */
    input  wire logic [HDR_W-1:0] serdes_rx_hdr,
    input  wire logic             serdes_rx_hdr_valid,
    output wire logic             serdes_rx_bitslip,

    /*
     * Status
     */
    output wire logic             rx_block_lock
);

// check configuration
if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2");

// IEEE 802.3 Clause 49 / 82 block sync state machine
// States
localparam [1:0]
    LOCK_INIT       = 2'd0,
    RESET_CNT       = 2'd1,
    TEST_SH         = 2'd2,
    VALID_SH        = 2'd3;

logic [1:0] state_reg;
logic [1:0] state_next;

// FIX: Removed inline initializers (= 6'b0 / = 4'b0) from declarations below.
// VCS/Xcelium ICPD_INIT error: variables driven by always_ff cannot also have
// an inline procedural initializer. Reset is now handled inside always_ff.
logic [5:0] sh_count_reg;
logic [5:0] sh_count_next;
logic [3:0] sh_invalid_count_reg;
logic [3:0] sh_invalid_count_next;

// Additional pipeline registers (these are only written by always_ff
// and never have competing inline initializers - safe to keep as-is)
logic                 bitslip_count_reg;
logic                 bitslip_count_next;
logic                 bitslip_reg;
logic                 bitslip_next;
logic                 lock_reg;
logic                 lock_next;

assign serdes_rx_bitslip = bitslip_reg;
assign rx_block_lock     = lock_reg;

wire hdr_valid = serdes_rx_hdr == 2'b10 || serdes_rx_hdr == 2'b01;

always_comb begin
    state_next            = state_reg;
    sh_count_next         = sh_count_reg;
    sh_invalid_count_next = sh_invalid_count_reg;
    bitslip_count_next    = bitslip_count_reg;
    bitslip_next          = 1'b0;
    lock_next             = lock_reg;

    if (!serdes_rx_hdr_valid) begin
        // stall - do nothing
    end else begin
        case (state_reg)
            LOCK_INIT: begin
                sh_count_next         = '0;
                sh_invalid_count_next = '0;
                lock_next             = 1'b0;
                state_next            = RESET_CNT;
            end

            RESET_CNT: begin
                sh_count_next = '0;
                if (hdr_valid) begin
                    state_next = TEST_SH;
                end else begin
                    // invalid header - slip
                    if (bitslip_count_reg) begin
                        bitslip_next       = 1'b0;
                        bitslip_count_next = 1'b0;
                    end else begin
                        bitslip_next       = 1'b1;
                        bitslip_count_next = 1'b1;
                    end
                end
            end

            TEST_SH: begin
                sh_count_next = sh_count_reg + 1;
                if (!hdr_valid) begin
                    sh_invalid_count_next = sh_invalid_count_reg + 1;
                end

                if (sh_count_reg == 6'd63) begin
                    if (sh_invalid_count_reg == 4'd0) begin
                        state_next = VALID_SH;
                        lock_next  = 1'b1;
                    end else begin
                        state_next = RESET_CNT;
                        lock_next  = 1'b0;
                    end
                end
            end

            VALID_SH: begin
                sh_count_next = sh_count_reg + 1;
                if (!hdr_valid) begin
                    sh_invalid_count_next = sh_invalid_count_reg + 1;
                end

                if (sh_count_reg == 6'd63) begin
                    if (sh_invalid_count_reg > 4'd0) begin
                        state_next = RESET_CNT;
                        lock_next  = 1'b0;
                    end else begin
                        sh_count_next         = '0;
                        sh_invalid_count_next = '0;
                    end
                end
            end

            default: begin
                state_next = LOCK_INIT;
            end
        endcase
    end
end

// FIX: sh_count_reg and sh_invalid_count_reg are now reset here
// instead of via inline initializers on the declarations.
always_ff @(posedge clk) begin
    if (rst) begin
        state_reg             <= LOCK_INIT;
        sh_count_reg          <= 6'b0;
        sh_invalid_count_reg  <= 4'b0;
        bitslip_count_reg     <= 1'b0;
        bitslip_reg           <= 1'b0;
        lock_reg              <= 1'b0;
    end else begin
        state_reg             <= state_next;
        sh_count_reg          <= sh_count_next;
        sh_invalid_count_reg  <= sh_invalid_count_next;
        bitslip_count_reg     <= bitslip_count_next;
        bitslip_reg           <= bitslip_next;
        lock_reg              <= lock_next;
    end
end

endmodule

`resetall