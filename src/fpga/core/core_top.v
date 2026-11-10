// =============================================================================
// core_top.v - Spy Hunter (Bally Midway, 1983) core for Analogue Pocket
//
// Hardware: MCR3 board family (same as Tapper). Three CPUs:
//   - Z80 main         @ ~2.5 MHz  (program, video, gameplay)
//   - Z80 SSIO sound   @ ~2 MHz    (dual AY-3-8910, sound effects)
//   - Motorola 68000   @ 8 MHz     (Cheap Squeak Deluxe music/voice)
//
// ROM image (0x41000 bytes, loaded via APF data slot 1):
//   0x00000-0x0DFFF  Main Z80 program  (cpu_rom 64 KB dpram, only 56 KB used)
//   0x0E000-0x0FFFF  SSIO sound prog   (snd_rom 8 KB dpram)
//   0x10000-0x17FFF  CSD m68k prog     (csd_rom 32 KB, byte-paired to 16-bit)
//   0x18000-0x37FFF  Sprite graphics   (sprite_rom 32K x 32-bit, 4 byte lanes)
//   0x38000-0x40FFF  BG + alpha        (spy_hunter.dl_addr internal BRAMs)
//
// Reuses load-bearing patterns from Tapper:
//   - data_loader (dcfifo CDC for bridge -> clk_sys ROM writes)
//   - rom_loaded = dataslot_allcomplete (not dn_addr triggers)
//   - game_reset_n = reset_n_sys & rom_loaded & settle_counter==0
//   - box-filter audio decimator (~39 kHz; never point-sample)
//   - 24-bit RGB gated to black during hblank | vblank
//   - 4-lane sprite ROM (each lane = contiguous 32 KB chunk)
//   - T80 boot-fixed (RegsH/L power-up = 0xFF, from Tapper)
//
// Spy Hunter-specific:
//   - CSD ROM is 16-bit wide. Two 16 KB byte-BRAMs combined: csd_lo (u17, u18)
//     and csd_hi (u7, u8). Reads concatenate {csd_hi, csd_lo} = 16-bit word.
//   - csd_audio_out is 10-bit. Mixed into audio_l/r at <<5 (per MiSTer top).
//   - Analog steering/gas: spy_hunter_control entity emulates 8-bit values from
//     DPAD up/down (gas) and left/right (steering). No raw analog joy used.
//   - 6 buttons: gun, missile, smoke, oil, van, shift. Face A/B/X/Y + START +
//     LEFT TRIG. SELECT = coin1. No game-level START button (coin starts).
// =============================================================================

`default_nettype none

module core_top (

// -- Physical connections ----------------------------------------------------

input  wire        clk_74a,
input  wire        clk_74b,

inout  wire [7:0]  cart_tran_bank2,    output wire cart_tran_bank2_dir,
inout  wire [7:0]  cart_tran_bank3,    output wire cart_tran_bank3_dir,
inout  wire [7:0]  cart_tran_bank1,    output wire cart_tran_bank1_dir,
inout  wire [7:4]  cart_tran_bank0,    output wire cart_tran_bank0_dir,
inout  wire        cart_tran_pin30,    output wire cart_tran_pin30_dir,
output wire        cart_pin30_pwroff_reset,
inout  wire        cart_tran_pin31,    output wire cart_tran_pin31_dir,

input  wire        port_ir_rx,
output wire        port_ir_tx,
output wire        port_ir_rx_disable,

inout  wire        port_tran_si,       output wire port_tran_si_dir,
inout  wire        port_tran_so,       output wire port_tran_so_dir,
inout  wire        port_tran_sck,      output wire port_tran_sck_dir,
inout  wire        port_tran_sd,       output wire port_tran_sd_dir,

output wire [21:16] cram0_a,    inout  wire [15:0] cram0_dq,
input  wire          cram0_wait, output wire        cram0_clk,
output wire          cram0_adv_n, output wire       cram0_cre,
output wire          cram0_ce0_n, output wire       cram0_ce1_n,
output wire          cram0_oe_n,  output wire       cram0_we_n,
output wire          cram0_ub_n,  output wire       cram0_lb_n,

output wire [21:16] cram1_a,    inout  wire [15:0] cram1_dq,
input  wire          cram1_wait, output wire        cram1_clk,
output wire          cram1_adv_n, output wire       cram1_cre,
output wire          cram1_ce0_n, output wire       cram1_ce1_n,
output wire          cram1_oe_n,  output wire       cram1_we_n,
output wire          cram1_ub_n,  output wire       cram1_lb_n,

output wire [12:0] dram_a,    output wire [1:0]  dram_ba,
inout  wire [15:0] dram_dq,   output wire [1:0]  dram_dqm,
output wire        dram_clk,  output wire        dram_cke,
output wire        dram_ras_n, output wire       dram_cas_n,
output wire        dram_we_n,

output wire [16:0] sram_a,    inout  wire [15:0] sram_dq,
output wire        sram_oe_n, output wire        sram_we_n,
output wire        sram_ub_n, output wire        sram_lb_n,

input  wire        vblank,
output wire        vpll_feed,
output wire        dbg_tx,
input  wire        dbg_rx,
output wire        user1,
input  wire        user2,
inout  wire        aux_sda,
output wire        aux_scl,

output wire [23:0] video_rgb,
output wire        video_rgb_clock,
output wire        video_rgb_clock_90,
output wire        video_de,
output wire        video_skip,
output wire        video_vs,
output wire        video_hs,

output wire        audio_mclk,
input  wire        audio_adc,
output wire        audio_dac,
output wire        audio_lrck,

output wire        bridge_endian_little,
input  wire [31:0] bridge_addr,
input  wire        bridge_rd,
output reg  [31:0] bridge_rd_data,
input  wire        bridge_wr,
input  wire [31:0] bridge_wr_data,

input  wire [31:0] cont1_key,
input  wire [31:0] cont2_key,
input  wire [31:0] cont3_key,
input  wire [31:0] cont4_key,
input  wire [31:0] cont1_joy,
input  wire [31:0] cont2_joy,
input  wire [31:0] cont3_joy,
input  wire [31:0] cont4_joy,
input  wire [15:0] cont1_trig,
input  wire [15:0] cont2_trig,
input  wire [15:0] cont3_trig,
input  wire [15:0] cont4_trig

);

// -- Tie off unused physical ports -------------------------------------------
assign port_ir_tx              = 1'b0;
assign port_ir_rx_disable      = 1'b1;

assign cart_tran_bank3         = 8'hZZ;   assign cart_tran_bank3_dir     = 1'b0;
assign cart_tran_bank2         = 8'hZZ;   assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hZZ;   assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0         = 4'hF;    assign cart_tran_bank0_dir     = 1'b1;
assign cart_tran_pin30         = 1'b0;    assign cart_tran_pin30_dir     = 1'bZ;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31         = 1'bZ;    assign cart_tran_pin31_dir     = 1'b0;

assign port_tran_so            = 1'bZ;    assign port_tran_so_dir        = 1'b0;
assign port_tran_si            = 1'bZ;    assign port_tran_si_dir        = 1'b0;
assign port_tran_sck           = 1'bZ;    assign port_tran_sck_dir       = 1'b0;
assign port_tran_sd            = 1'bZ;    assign port_tran_sd_dir        = 1'b0;

assign cram0_a = 6'h0;  assign cram0_dq = 16'hZZZZ; assign cram0_clk = 1'b0;
assign cram0_adv_n = 1'b1; assign cram0_cre = 1'b0;
assign cram0_ce0_n = 1'b1; assign cram0_ce1_n = 1'b1;
assign cram0_oe_n = 1'b1; assign cram0_we_n = 1'b1;
assign cram0_ub_n = 1'b1; assign cram0_lb_n = 1'b1;

assign cram1_a = 6'h0;  assign cram1_dq = 16'hZZZZ; assign cram1_clk = 1'b0;
assign cram1_adv_n = 1'b1; assign cram1_cre = 1'b0;
assign cram1_ce0_n = 1'b1; assign cram1_ce1_n = 1'b1;
assign cram1_oe_n = 1'b1; assign cram1_we_n = 1'b1;
assign cram1_ub_n = 1'b1; assign cram1_lb_n = 1'b1;

assign dram_a = 13'h0; assign dram_ba = 2'h0; assign dram_dq = 16'hZZZZ;
assign dram_dqm = 2'h3; assign dram_clk = 1'b0; assign dram_cke = 1'b0;
assign dram_ras_n = 1'b1; assign dram_cas_n = 1'b1; assign dram_we_n = 1'b1;

assign sram_a = 17'h0; assign sram_dq = 16'hZZZZ;
assign sram_oe_n = 1'b1; assign sram_we_n = 1'b1;
assign sram_ub_n = 1'b1; assign sram_lb_n = 1'b1;

assign vpll_feed = 1'bZ;
assign dbg_tx    = 1'bZ;
assign user1     = 1'bZ;
assign aux_scl   = 1'bZ;

assign bridge_endian_little = 1'b0;  // big-endian

// -- PLL ---------------------------------------------------------------------
// 74.25 MHz in -> 40 MHz (clk_sys / spy_hunter.clock_40)
//                10 MHz (clk_vid / pixel clock)
//                10 MHz 90deg (clk_vid_90 / APF DDR pixel clock)
wire clk_sys;
wire clk_vid;
wire clk_vid_90;
wire pll_locked;
wire pll_locked_s;

mf_pllbase mp1 (
    .refclk   (clk_74a),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_vid),
    .outclk_2 (clk_vid_90),
    .locked   (pll_locked)
);

synch_3 s_pll (pll_locked, pll_locked_s, clk_74a);

// -- APF bridge command handler ----------------------------------------------
wire        reset_n;
wire [31:0] cmd_bridge_rd_data;

wire        status_boot_done  = pll_locked_s;
wire        status_setup_done = rom_loaded_s;
wire        status_running    = 1'b1;

wire        dataslot_requestread;
wire [15:0] dataslot_requestread_id;
wire        dataslot_requestread_ack  = 1'b1;
wire        dataslot_requestread_ok   = 1'b1;

wire        dataslot_requestwrite;
wire [15:0] dataslot_requestwrite_id;
wire [31:0] dataslot_requestwrite_size;
wire        dataslot_requestwrite_ack = 1'b1;
wire        dataslot_requestwrite_ok  = 1'b1;

wire        dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire        dataslot_allcomplete;

wire [31:0] rtc_epoch_seconds;
wire [31:0] rtc_date_bcd;
wire [31:0] rtc_time_bcd;
wire        rtc_valid;

wire        savestate_supported   = 1'b0;
wire [31:0] savestate_addr        = 32'h0;
wire [31:0] savestate_size        = 32'h0;
wire [31:0] savestate_maxloadsize = 32'h0;
wire        savestate_start;
wire        savestate_start_ack  = 1'b0;
wire        savestate_start_busy = 1'b0;
wire        savestate_start_ok   = 1'b0;
wire        savestate_start_err  = 1'b0;
wire        savestate_load;
wire        savestate_load_ack  = 1'b0;
wire        savestate_load_busy = 1'b0;
wire        savestate_load_ok   = 1'b0;
wire        savestate_load_err  = 1'b0;
wire        osnotify_inmenu;

reg         target_dataslot_read     = 1'b0;
reg         target_dataslot_write    = 1'b0;
reg         target_dataslot_getfile  = 1'b0;
reg         target_dataslot_openfile = 1'b0;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
reg  [15:0] target_dataslot_id         = 16'h0;
reg  [31:0] target_dataslot_slotoffset = 32'h0;
reg  [31:0] target_dataslot_bridgeaddr = 32'h0;
reg  [31:0] target_dataslot_length     = 32'h0;
wire [31:0] target_buffer_param_struct;
wire [31:0] target_buffer_resp_struct;

wire [9:0]  datatable_addr;
wire        datatable_wren;
wire [31:0] datatable_data;
wire [31:0] datatable_q;

core_bridge_cmd icb (
    .clk                       (clk_74a),
    .reset_n                   (reset_n),
    .bridge_endian_little      (bridge_endian_little),
    .bridge_addr               (bridge_addr),
    .bridge_rd                 (bridge_rd),
    .bridge_rd_data            (cmd_bridge_rd_data),
    .bridge_wr                 (bridge_wr),
    .bridge_wr_data            (bridge_wr_data),
    .status_boot_done          (status_boot_done),
    .status_setup_done         (status_setup_done),
    .status_running            (status_running),
    .dataslot_requestread      (dataslot_requestread),
    .dataslot_requestread_id   (dataslot_requestread_id),
    .dataslot_requestread_ack  (dataslot_requestread_ack),
    .dataslot_requestread_ok   (dataslot_requestread_ok),
    .dataslot_requestwrite     (dataslot_requestwrite),
    .dataslot_requestwrite_id  (dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack (dataslot_requestwrite_ack),
    .dataslot_requestwrite_ok  (dataslot_requestwrite_ok),
    .dataslot_update           (dataslot_update),
    .dataslot_update_id        (dataslot_update_id),
    .dataslot_update_size      (dataslot_update_size),
    .dataslot_allcomplete      (dataslot_allcomplete),
    .rtc_epoch_seconds         (rtc_epoch_seconds),
    .rtc_date_bcd              (rtc_date_bcd),
    .rtc_time_bcd              (rtc_time_bcd),
    .rtc_valid                 (rtc_valid),
    .savestate_supported       (savestate_supported),
    .savestate_addr            (savestate_addr),
    .savestate_size            (savestate_size),
    .savestate_maxloadsize     (savestate_maxloadsize),
    .savestate_start           (savestate_start),
    .savestate_start_ack       (savestate_start_ack),
    .savestate_start_busy      (savestate_start_busy),
    .savestate_start_ok        (savestate_start_ok),
    .savestate_start_err       (savestate_start_err),
    .savestate_load            (savestate_load),
    .savestate_load_ack        (savestate_load_ack),
    .savestate_load_busy       (savestate_load_busy),
    .savestate_load_ok         (savestate_load_ok),
    .savestate_load_err        (savestate_load_err),
    .osnotify_inmenu           (osnotify_inmenu),
    .target_dataslot_read      (target_dataslot_read),
    .target_dataslot_write     (target_dataslot_write),
    .target_dataslot_getfile   (target_dataslot_getfile),
    .target_dataslot_openfile  (target_dataslot_openfile),
    .target_dataslot_ack       (target_dataslot_ack),
    .target_dataslot_done      (target_dataslot_done),
    .target_dataslot_err       (target_dataslot_err),
    .target_dataslot_id        (target_dataslot_id),
    .target_dataslot_slotoffset(target_dataslot_slotoffset),
    .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr),
    .target_dataslot_length    (target_dataslot_length),
    .target_buffer_param_struct(target_buffer_param_struct),
    .target_buffer_resp_struct (target_buffer_resp_struct),
    .datatable_addr            (datatable_addr),
    .datatable_wren            (datatable_wren),
    .datatable_data            (datatable_data),
    .datatable_q               (datatable_q)
);

// -- Interact menu: SFX / Music volume (interact.json ids 0,1) ---------------
// 0..10 = 0..100 %, default 10 (= the mix as tested). Written by APF in the
// clk_74a domain; values above 10 are clamped. Read back for the menu.
reg [3:0] vol_sfx_74   = 4'd10;
reg [3:0] vol_music_74 = 4'd10;
// DIP switches (SSIO IP3) + service switch (IP0 bit 7), interact ids 2..4.
// Defaults = MAME spyhunt: Game Timer 1:30, Demo Sounds On, service off.
reg opt_timer_74   = 1'b1;   // 1 = 1:30, 0 = 1:00
reg opt_demo_74    = 1'b1;   // 1 = demo sounds ON
reg opt_service_74 = 1'b0;   // 1 = service/test mode switch ON
always @(posedge clk_74a) begin
    if (bridge_wr && bridge_addr == 32'h20000000)
        vol_sfx_74   <= (bridge_wr_data > 32'd10) ? 4'd10 : bridge_wr_data[3:0];
    if (bridge_wr && bridge_addr == 32'h20000004)
        vol_music_74 <= (bridge_wr_data > 32'd10) ? 4'd10 : bridge_wr_data[3:0];
    if (bridge_wr && bridge_addr == 32'h20000008) opt_timer_74   <= bridge_wr_data[0];
    if (bridge_wr && bridge_addr == 32'h2000000C) opt_demo_74    <= bridge_wr_data[0];
    if (bridge_wr && bridge_addr == 32'h20000010) opt_service_74 <= bridge_wr_data[0];
end

always @(*) begin
    casex (bridge_addr)
        32'hF8xxxxxx: bridge_rd_data = cmd_bridge_rd_data;
        32'h20000000: bridge_rd_data = {28'd0, vol_sfx_74};
        32'h20000004: bridge_rd_data = {28'd0, vol_music_74};
        32'h20000008: bridge_rd_data = {31'd0, opt_timer_74};
        32'h2000000C: bridge_rd_data = {31'd0, opt_demo_74};
        32'h20000010: bridge_rd_data = {31'd0, opt_service_74};
        default:      bridge_rd_data = 32'h0;
    endcase
end

// into clk_sys (static levels)
reg [2:0] opt_s1, opt_s;
always @(posedge clk_sys) begin
    opt_s1 <= {opt_service_74, opt_demo_74, opt_timer_74};
    opt_s  <= opt_s1;
end
wire opt_timer = opt_s[0], opt_demo = opt_s[1], opt_service = opt_s[2];

// -- ROM loading via APF bridge ----------------------------------------------
// Spy Hunter image is 0x41000 bytes -> dn_addr needs 19 bits.

wire [18:0] dn_addr;
wire [7:0]  dn_data;
wire        dn_wr;
reg         rom_loaded_74 = 1'b0;
wire        rom_loaded;
wire        rom_loaded_s = rom_loaded_74;

synch_3 s_rom_to_sys (rom_loaded_74, rom_loaded, clk_sys);

data_loader #(
    .ADDRESS_MASK_UPPER_4 (4'h0),
    .ADDRESS_SIZE         (18),       // 19-bit dn_addr (covers 0x41000)
    .OUTPUT_WORD_SIZE     (1)
) u_rom_loader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),
    .bridge_wr            (bridge_wr),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_wr_data       (bridge_wr_data),
    .write_en             (dn_wr),
    .write_addr           (dn_addr),
    .write_data           (dn_data)
);

always @(posedge clk_74a) begin
    if (dataslot_allcomplete)
        rom_loaded_74 <= 1'b1;
end

// -- ROM region demux from dn_addr -------------------------------------------
//   0x00000-0x0DFFF  cpu_rom         (56 KB used out of 64 KB allocated)
//   0x0E000-0x0FFFF  snd_rom         (8 KB)
//   0x10000-0x13FFF  csd_rom_lo      (16 KB: u17, u18) -> LSB of CSD 16-bit
//   0x14000-0x17FFF  csd_rom_hi      (16 KB: u7,  u8)  -> MSB of CSD 16-bit
//   0x18000-0x37FFF  sprite_rom      (128 KB, 4 lanes of 32 KB)
//   0x38000-0x40FFF  spy_hunter.dl_addr (BG 32 KB + alpha 4 KB)

wire dn_is_cpu    = (dn_addr <  19'h0E000);
wire dn_is_snd    = (dn_addr >= 19'h0E000) && (dn_addr < 19'h10000);
wire dn_is_csd_lo = (dn_addr >= 19'h10000) && (dn_addr < 19'h14000);
wire dn_is_csd_hi = (dn_addr >= 19'h14000) && (dn_addr < 19'h18000);
wire dn_is_sprite = (dn_addr >= 19'h18000) && (dn_addr < 19'h38000);
wire dn_is_dl     = (dn_addr >= 19'h38000) && (dn_addr < 19'h41000);

wire cpu_rom_we    = dn_wr && dn_is_cpu;
wire snd_rom_we    = dn_wr && dn_is_snd;
wire csd_lo_we     = dn_wr && dn_is_csd_lo;
wire csd_hi_we     = dn_wr && dn_is_csd_hi;
wire sprite_rom_we = dn_wr && dn_is_sprite;
wire dl_wr_gated   = dn_wr && dn_is_dl;

wire [18:0] sprite_byte_offset = dn_addr - 19'h18000;
// dl_addr_offset: dn_addr 0x38000 -> dl 0x0000 (BG1)
//                 dn_addr 0x40000 -> dl 0x8000 (alpha)
// dn_addr[15:0] of 0x38000 = 0x8000, so subtract 0x8000 from dn_addr[15:0].
wire [15:0] dl_addr_offset = dn_addr[15:0] - 16'h8000;

// -- Reset --------------------------------------------------------------------
wire reset_n_sys;
synch_3 s_resetn (reset_n, reset_n_sys, clk_sys);

reg [7:0] reset_ctr = 8'hFF;
wire      game_reset_n = (reset_ctr == 8'h0) && rom_loaded && reset_n_sys;
wire      game_reset   = !game_reset_n;

always @(posedge clk_sys) begin
    if (!pll_locked)
        reset_ctr <= 8'hFF;
    else if (reset_ctr != 8'h0)
        reset_ctr <= reset_ctr - 1'd1;
end

// -- CPU ROM (64 KB) ---------------------------------------------------------
wire [15:0] cpu_rom_addr;
reg  [7:0]  cpu_rom_do_r;
(* ramstyle = "M10K" *) reg [7:0] cpu_rom_mem [0:65535];
always @(posedge clk_sys) begin
    if (cpu_rom_we) cpu_rom_mem[dn_addr[15:0]] <= dn_data;
    cpu_rom_do_r <= cpu_rom_mem[cpu_rom_addr];
end

// -- SSIO Sound ROM (8 KB) ---------------------------------------------------
// Pre-init from snd_rom.hex at FPGA config time so byte 0 (Z80 reset vector)
// is guaranteed correct -- avoids any data_loader stream timing issues that
// could leave the SSIO Z80 executing garbage. Tapper pattern.
wire [12:0] snd_rom_addr;
reg  [7:0]  snd_rom_do_r;
(* ramstyle = "M10K" *) reg [7:0] snd_rom_mem [0:8191];
initial $readmemh("snd_rom.hex", snd_rom_mem);
wire [12:0] snd_rom_waddr = dn_addr[12:0];   // 0x0E000-0x0FFFF maps to 0x0000-0x1FFF
always @(posedge clk_sys) begin
    if (snd_rom_we) snd_rom_mem[snd_rom_waddr] <= dn_data;
    snd_rom_do_r <= snd_rom_mem[snd_rom_addr];
end

// -- CSD ROM (16-bit, 32 KB = 16 K words x 16) -------------------------------
// 4 byte chips paired into 16-bit words by MCR3 CSD board:
//   word 0x0000-0x1FFF  -> {u7 [n], u17[n]}  (lower 16 KB of CSD addr space)
//   word 0x2000-0x3FFF  -> {u8 [n], u18[n]}  (upper 16 KB)
// Implemented as two 16 KB byte BRAMs. csd_lo concatenates u17 || u18;
// csd_hi concatenates u7 || u8. word_addr maps directly through.

wire [14:1] csd_rom_addr;                     // spy_hunter declares [14:1]
reg  [7:0]  csd_lo_do_r, csd_hi_do_r;
wire [15:0] csd_rom_do = {csd_hi_do_r, csd_lo_do_r};

(* ramstyle = "M10K" *) reg [7:0] csd_lo_mem [0:16383];
(* ramstyle = "M10K" *) reg [7:0] csd_hi_mem [0:16383];
wire [13:0] csd_waddr = dn_addr[13:0];        // mask 0x10000-0x13FFF and 0x14000-0x17FFF
always @(posedge clk_sys) begin
    if (csd_lo_we) csd_lo_mem[csd_waddr] <= dn_data;
    if (csd_hi_we) csd_hi_mem[csd_waddr] <= dn_data;
    csd_lo_do_r <= csd_lo_mem[csd_rom_addr];
    csd_hi_do_r <= csd_hi_mem[csd_rom_addr];
end

// -- Sprite ROM (32K x 32-bit, 4 byte lanes) ---------------------------------
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b0 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b1 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b2 [0:32767];
(* ramstyle = "M10K" *) reg [7:0] sprite_rom_b3 [0:32767];
reg  [7:0]  spr_b0_r, spr_b1_r, spr_b2_r, spr_b3_r;
wire [14:0] sp_addr;
wire [31:0] sp_graphx32_do = {spr_b3_r, spr_b2_r, spr_b1_r, spr_b0_r};

// Each lane = a contiguous 32 KB chunk of the sprite section (Tapper pattern).
wire [14:0] sprite_row     = sprite_byte_offset[14:0];
wire [1:0]  sprite_byte_ln = sprite_byte_offset[16:15];

always @(posedge clk_sys) begin
    if (sprite_rom_we) begin
        case (sprite_byte_ln)
            2'd0: sprite_rom_b0[sprite_row] <= dn_data;
            2'd1: sprite_rom_b1[sprite_row] <= dn_data;
            2'd2: sprite_rom_b2[sprite_row] <= dn_data;
            2'd3: sprite_rom_b3[sprite_row] <= dn_data;
        endcase
    end
    spr_b0_r <= sprite_rom_b0[sp_addr];
    spr_b1_r <= sprite_rom_b1[sp_addr];
    spr_b2_r <= sprite_rom_b2[sp_addr];
    spr_b3_r <= sprite_rom_b3[sp_addr];
end

// -- Controller mapping ------------------------------------------------------
// Pocket cont1_key (APF standard):
//   [0..3]  DPAD up/down/left/right
//   [4..7]  Face A/B/X/Y
//   [8..9]  Left/Right trigger
//   [14]    Select
//   [15]    Start
//
// Spy Hunter (no in-game start; coin starts the game):
//   SELECT -> coin1
//   A (gun), B (missile), X (smoke), Y (oil) -> 4 weapon buttons
//   START  -> weapons van (drive into the back of)
//   L TRIG -> gear shift
//
// Steering (8-bit) + gas (8-bit) come from spy_hunter_control: DPAD up/down
// modulates gas, DPAD left/right modulates steering. Analog joy not used.

wire m_coin    = cont1_key[14];

// Coinage workaround: 1 Pocket SELECT press = 2 coin1 pulses internally.
// Spy Hunter's default coinage (without NVRAM init load) is 2 coins / 1 credit
// on the coin1 slot. The pulse generator below converts a single SELECT press
// into two distinct coin1 rising edges so the user gets 1 credit per click.
reg        m_coin_prev    = 1'b0;
reg [1:0]  coin_state     = 2'd0;
reg [22:0] coin_timer     = 23'd0;
reg        coin1_internal = 1'b0;

localparam [22:0] COIN_PULSE_LEN = 23'd2_000_000;   // 50 ms at 40 MHz
localparam [22:0] COIN_GAP_LEN   = 23'd2_000_000;   // 50 ms gap

always @(posedge clk_sys) begin
    m_coin_prev <= m_coin;
    case (coin_state)
        2'd0: begin
            coin1_internal <= 1'b0;
            if (m_coin && !m_coin_prev) begin       // rising edge of SELECT
                coin1_internal <= 1'b1;
                coin_timer     <= COIN_PULSE_LEN;
                coin_state     <= 2'd1;
            end
        end
        2'd1: begin                                  // first pulse high
            coin1_internal <= 1'b1;
            if (coin_timer == 23'd0) begin
                coin1_internal <= 1'b0;
                coin_timer     <= COIN_GAP_LEN;
                coin_state     <= 2'd2;
            end else coin_timer <= coin_timer - 1'b1;
        end
        2'd2: begin                                  // gap (coin1 low)
            coin1_internal <= 1'b0;
            if (coin_timer == 23'd0) begin
                coin1_internal <= 1'b1;
                coin_timer     <= COIN_PULSE_LEN;
                coin_state     <= 2'd3;
            end else coin_timer <= coin_timer - 1'b1;
        end
        2'd3: begin                                  // second pulse high
            coin1_internal <= 1'b1;
            if (coin_timer == 23'd0) begin
                coin1_internal <= 1'b0;
                coin_state     <= 2'd0;
            end else coin_timer <= coin_timer - 1'b1;
        end
    endcase
end

wire m_gun     = cont1_key[4];
wire m_missile = cont1_key[5];
wire m_smoke   = cont1_key[6];
wire m_oil     = cont1_key[7];
wire m_van     = cont1_key[15];
wire m_shift   = cont1_key[8];

wire m_up      = cont1_key[0];
wire m_down    = cont1_key[1];
wire m_left    = cont1_key[2];
wire m_right   = cont1_key[3];

wire [7:0] steering_emu, gas_emu;

spy_hunter_control u_ctrl (
    .clock_40       (clk_sys),
    .reset          (game_reset),
    .vsync          (vid_vs),
    .gas_plus       (m_up),
    .gas_minus      (m_down),
    .steering_plus  (m_right),
    .steering_minus (m_left),
    .steering       (steering_emu),
    .gas            (gas_emu)
);

// -- Spy Hunter game core (VHDL entity) --------------------------------------
wire [2:0]  vid_r, vid_g, vid_b;
wire        vid_hs, vid_vs, vid_hblank, vid_vblank, vid_ce;
wire [15:0] audio_l_raw, audio_r_raw;
wire [9:0]  csd_audio;

spy_hunter spy_hunter_core (
    .clock_40       (clk_sys),
    .reset          (game_reset),
    .tv15Khz_mode   (1'b0),                     // 31kHz progressive (494x480)

    .video_r        (vid_r),
    .video_g        (vid_g),
    .video_b        (vid_b),
    .video_csync    (),
    .video_hblank   (vid_hblank),
    .video_Vblank   (vid_vblank),
    .video_hs       (vid_hs),
    .video_vs       (vid_vs),
    .video_ce       (vid_ce),

    .separate_audio (1'b0),
    .audio_out_l    (audio_l_raw),
    .audio_out_r    (audio_r_raw),
    .csd_audio_out  (csd_audio),

    .coin1          (coin1_internal),   // 2-pulse generator (see above)
    .coin2          (1'b0),
    .shift          (m_shift),
    .oil            (m_oil),
    .missile        (m_missile),
    .van            (m_van),
    .smoke          (m_smoke),
    .gun            (m_gun),
    .show_lamps     (1'b0),
    .steering       (steering_emu),
    .gas            (gas_emu),
    .timer          (opt_timer),        // IP3 bit0: 1 = 1:30 (MAME default), 0 = 1:00
    .demo_sound     (~opt_demo),        // IP3 bit1: 0 = demo sounds ON (MAME default)
    .service        (opt_service),      // IP0 bit7 service switch, from the menu

    .cpu_rom_addr   (cpu_rom_addr),
    .cpu_rom_do     (cpu_rom_do_r),
    .snd_rom_addr   (snd_rom_addr),
    .snd_rom_do     (snd_rom_do_r),
    .csd_rom_addr   (csd_rom_addr),
    .csd_rom_do     (csd_rom_do),
    .sp_addr        (sp_addr),
    .sp_graphx32_do (sp_graphx32_do),

    .dl_addr        (dl_addr_offset),
    .dl_data        (dn_data),
    .dl_wr          (dl_wr_gated),
    .dbg_cpu_addr   ()
);

// -- Video output ------------------------------------------------------------
// 3-3-3 RGB. Replicate top bits to fill 8-bit channels.
wire [7:0] rgb_r = {vid_r, vid_r, vid_r[2:1]};
wire [7:0] rgb_g = {vid_g, vid_g, vid_g[2:1]};
wire [7:0] rgb_b = {vid_b, vid_b, vid_b[2:1]};
wire [23:0] rgb_out = (vid_hblank | vid_vblank) ? 24'h0 : {rgb_r, rgb_g, rgb_b};

reg [23:0] vid_rgb_r;
reg        vid_hs_r, vid_vs_r, vid_de_r;

always @(posedge clk_vid) begin
    vid_rgb_r <= rgb_out;
    vid_hs_r  <= vid_hs;
    vid_vs_r  <= vid_vs;
    vid_de_r  <= ~(vid_hblank | vid_vblank);
end

assign video_rgb          = vid_rgb_r;
assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_de           = vid_de_r;
assign video_skip         = 1'b0;
assign video_vs           = vid_vs_r;
assign video_hs           = vid_hs_r;

// -- Audio -------------------------------------------------------------------
// SSIO outputs 16-bit unsigned (audio_l/r). CSD outputs 10-bit (csd_audio).
// Mix exactly as MiSTer top does: AUDIO = audio_l + {csd_audio, 5'd0}.
// Natural 16-bit wrap on rare overflow (clicks instead of dropouts).
// Earlier saturating mix at <<6 made CSD 2x too loud and clipped SSIO
// SFX to silence when music + effect overlapped.
// Same 40 MHz / 1024 box-filter decimator that worked for Tapper.

wire [15:0] csd_audio_ext = {1'b0, csd_audio, 5'd0};  // 10-bit -> 16-bit (<<5, matches MiSTer)

// Menu volumes, synchronised into clk_sys (quasi-static; a one-sample tear
// while the user moves the slider is inaudible). Gain = vol * 25.6 (x/256).
reg [3:0] vol_sfx_s1, vol_sfx, vol_music_s1, vol_music;
always @(posedge clk_sys) begin
    vol_sfx_s1   <= vol_sfx_74;   vol_sfx   <= vol_sfx_s1;
    vol_music_s1 <= vol_music_74; vol_music <= vol_music_s1;
end
function [8:0] vol_gain(input [3:0] v);
    case (v)
        4'd0: vol_gain = 9'd0;    4'd1: vol_gain = 9'd26;  4'd2: vol_gain = 9'd51;
        4'd3: vol_gain = 9'd77;   4'd4: vol_gain = 9'd102; 4'd5: vol_gain = 9'd128;
        4'd6: vol_gain = 9'd154;  4'd7: vol_gain = 9'd179; 4'd8: vol_gain = 9'd205;
        4'd9: vol_gain = 9'd230;  default: vol_gain = 9'd256;
    endcase
endfunction
reg  [24:0] sfx_l_p, sfx_r_p, mus_p;
always @(posedge clk_sys) begin
    sfx_l_p <= audio_l_raw   * vol_gain(vol_sfx);
    sfx_r_p <= audio_r_raw   * vol_gain(vol_sfx);
    mus_p   <= csd_audio_ext * vol_gain(vol_music);
end

wire [15:0] audio_l_mixed = sfx_l_p[23:8] + mus_p[23:8];
wire [15:0] audio_r_mixed = sfx_r_p[23:8] + mus_p[23:8];

reg  [9:0]  aud_div     = 10'd0;
reg  [25:0] aud_accum_l = 26'd0, aud_accum_r = 26'd0;
reg  [15:0] audio_l_s   = 16'd0,  audio_r_s  = 16'd0;

always @(posedge clk_sys) begin
    aud_div <= aud_div + 1'd1;
    if (aud_div == 10'd0) begin
        audio_l_s   <= aud_accum_l[25:10];
        audio_r_s   <= aud_accum_r[25:10];
        aud_accum_l <= {10'd0, audio_l_mixed};
        aud_accum_r <= {10'd0, audio_r_mixed};
    end else begin
        aud_accum_l <= aud_accum_l + {10'd0, audio_l_mixed};
        aud_accum_r <= aud_accum_r + {10'd0, audio_r_mixed};
    end
end

sound_i2s #(
    .CHANNEL_WIDTH (16),
    .SIGNED_INPUT  (0)
) u_sound_i2s (
    .clk_74a    (clk_74a),
    .clk_audio  (clk_sys),
    .audio_l    (audio_l_s),
    .audio_r    (audio_r_s),
    .audio_mclk (audio_mclk),
    .audio_dac  (audio_dac),
    .audio_lrck (audio_lrck)
);

endmodule
