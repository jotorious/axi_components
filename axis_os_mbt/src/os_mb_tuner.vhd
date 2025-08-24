----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/12/2018 12:02:15 PM
-- Design Name: 
-- Module Name: os_sbt_tb - Testbed
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


--- This is an overlap save based sub band tuner
-----------------------------------------------

-- Data Flow is as follows:

------------------
-- Overlap P Inputs 
------------------
--      |
--      V
------------------
--     FFT (Xilinx IP - AXIS)
------------------
--      |
--      V
----------------------    -------------------------
-- Freq. Domain Mixing    RAM w/ Precalc'ed LPF DFT Coefs
----------------------    -------------------------
--      |                         |
--      V                         V
------------------------------------------
--         Complex Mult (Xilinx IP - AXIS)
------------------------------------------
--               |
--               V
------------------------------------------
--     Freq. Domain Downsampling
------------------------------------------
--               |
--               V
------------------------------------------
--             IFFT (Xilinx IP - AXIS)
------------------------------------------
--               |
--               V
------------------------------------------
--         Discard P Outputs
------------------------------------------
--               |
--               V


-- FOR A 1024 (2^10) POINT FFT, w/ Filter length 256 (2^8)
-- if we decimate by 16 (2^4), then the resulting IFFT is 64 (2^10 - 2^4 = 2^6) points. We stack Add 64 columns.
-- We can rotate by any number of bins, but if we were channelizing, the equally spaced channels we'd want would
-- be acquired by rotating 0, 64, 128, ... 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;
use work.overlap_save_pkg.all;
use work.axis_packet_mux_pkg.all;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity os_mb_tuner is
    generic (
        Nfft : integer := 1024;
        P    : integer := 256;

        DECIMATE : integer := 16;
        filter_file: string    := "filter_coefs.data";

        NUM_CHANNELS : integer := 4
    );
    port (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        
        -- AXI-Stream Slave (Input) Interface
        s_axis_data_tvalid : in std_logic;
        s_axis_data_tready : out std_logic;
        s_axis_data_tdata : in std_logic_vector(31 downto 0);
        s_axis_data_tlast : in std_logic;
        s_axis_data_tuser : in std_logic_vector(15 downto 0);
        
        -- AXI-Stream Master (Output) Interface
        m_axis_data_tvalid : out std_logic;
        m_axis_data_tready : in std_logic;
        m_axis_data_tdata : out std_logic_vector(31 downto 0);
        m_axis_data_tlast : out std_logic;
        m_axis_data_tuser : out std_logic_vector(15 downto 0);

        -- AXI-Lite Register Interface
        -- This is 64 Registers, that are 4 bytes each so, and axi addresses are byte addresses
        -- so Address width is 8
        reg_s_axi_AWADDR	: in std_logic_vector(7 downto 0);
        reg_s_axi_AWPROT	: in std_logic_vector(2 downto 0);
        reg_s_axi_AWVALID	: in std_logic;
        reg_s_axi_AWREADY	: out std_logic;
        reg_s_axi_WDATA	    : in std_logic_vector(31 downto 0);
        reg_s_axi_WSTRB	    : in std_logic_vector(3 downto 0);
        reg_s_axi_WVALID	: in std_logic;
        reg_s_axi_WREADY	: out std_logic;
        reg_s_axi_BRESP	    : out std_logic_vector(1 downto 0);
        reg_s_axi_BVALID	: out std_logic;
        reg_s_axi_BREADY	: in std_logic;
        reg_s_axi_ARADDR	: in std_logic_vector(7 downto 0);
        reg_s_axi_ARPROT	: in std_logic_vector(2 downto 0);
        reg_s_axi_ARVALID	: in std_logic;
        reg_s_axi_ARREADY	: out std_logic;
        reg_s_axi_RDATA	    : out std_logic_vector(31 downto 0);
        reg_s_axi_RRESP	    : out std_logic_vector(1 downto 0);
        reg_s_axi_RVALID	: out std_logic;
        reg_s_axi_RREADY	: in std_logic;
        
        --rc_axi_aclk    : IN STD_LOGIC;
        --rc_axi_aresetn : IN STD_LOGIC;
        rc_axi_awaddr  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        rc_axi_awprot  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        rc_axi_awvalid : IN STD_LOGIC;
        rc_axi_awready : OUT STD_LOGIC;
        rc_axi_wdata   : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        rc_axi_wstrb   : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        rc_axi_wvalid  : IN STD_LOGIC;
        rc_axi_wready  : OUT STD_LOGIC;
        rc_axi_bresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        rc_axi_bvalid  : OUT STD_LOGIC;
        rc_axi_bready  : IN STD_LOGIC;
        rc_axi_araddr  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        rc_axi_arprot  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        rc_axi_arvalid : IN STD_LOGIC;
        rc_axi_arready : OUT STD_LOGIC;
        rc_axi_rdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        rc_axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        rc_axi_rvalid  : OUT STD_LOGIC;
        rc_axi_rready  : IN STD_LOGIC
        
    );
end os_mb_tuner;

architecture structural of os_mb_tuner is


function f_log2 (x: positive) return integer is
  variable i : integer;
begin
  i := 0;
  while(2**i < x) and (i < 31) loop
    i := i + 1;
  end loop;
  return i;
end function;

  attribute mark_debug : string;
  attribute keep : string;
  --attribute mark_debug of mixer_dout : signal is "true";
  --attribute mark_debug of mult_dout : signal is "true";


  -- These all are still single streams
  signal dbg_axis_in : axi_stream32 := axis32_init;
  signal oi_dout : axi_stream32 := axis32_init;
  signal pktbuf_dout : axi_stream32 := axis32_init;  
  signal fft_dout : axi_stream32 := axis32_init;
  
  attribute mark_debug of dbg_axis_in : signal is "true";
  attribute mark_debug of oi_dout: signal is "true";
  attribute mark_debug of pktbuf_dout : signal is "true";
  attribute mark_debug of fft_dout : signal is "true";


  -- The mixer is the first piece where the streams are split.

  --type axis32_array is array 0 to NUM_CHANNELS-1 of axi_stream32;

  constant axis32_init : axi_stream32 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');

  --constant axis32_array_init : axis32_array := (others=> axis32_init);


  --signal mixer_dout : axis32_array := axis32_array_init;
  --signal mult_dout : axis32_array := axis32_array_init;
  --signal fifo_dout : axi_stream32 := axis32_init;
  signal decim_dout : axi_stream32 := axis32_init;
  signal ifft_dout : axi_stream32 := axis32_init;
  signal sbt_dout : axi_stream32 := axis32_init;
  
  
  attribute mark_debug of decim_dout : signal is "true";
  attribute mark_debug of ifft_dout : signal is "true";
  attribute mark_debug of sbt_dout : signal is "true";
  
  
  signal fft_cnfg : axi_stream16 := axis16_init;
  signal fft_status : axi_stream8 := axis8_init;
  signal mult_dout_dlong : std_logic_vector(63 downto 0);

  signal fanout_tdata     : type_tdata(0 to NUM_CHANNELS-1);
  signal fanout_tvalid    : type_tvalid(0 to NUM_CHANNELS-1);
  signal fanout_tlast     : type_tlast(0 to NUM_CHANNELS-1);
  signal fanout_tuser     : type_tuser24(0 to NUM_CHANNELS-1);
  signal fanout_tstrb     : type_tstrb(0 to NUM_CHANNELS-1);
  signal fanout_tready    : type_tready(0 to NUM_CHANNELS-1);

  signal mult_dout_tdata, mixer_dout_tdata     : type_tdata(0 to NUM_CHANNELS-1);
  signal mult_dout_tvalid, mixer_dout_tvalid   : type_tvalid(0 to NUM_CHANNELS-1);
  signal mult_dout_tlast, mixer_dout_tlast     : type_tlast(0 to NUM_CHANNELS-1);
  signal mult_dout_tuser, mixer_dout_tuser     : type_tuser24(0 to NUM_CHANNELS-1);
  signal mult_dout_tstrb, mixer_dout_tstrb     : type_tstrb(0 to NUM_CHANNELS-1);
  signal mult_dout_tready,mixer_dout_tready    : type_tready(0 to NUM_CHANNELS-1);

  signal fifo_dout_tdata     : type_tdata(0 to NUM_CHANNELS-1);
  signal fifo_dout_tvalid    : type_tvalid(0 to NUM_CHANNELS-1);
  signal fifo_dout_tlast     : type_tlast(0 to NUM_CHANNELS-1);
  signal fifo_dout_tuser     : type_tuser24(0 to NUM_CHANNELS-1);
  signal fifo_dout_tstrb     : type_tstrb(0 to NUM_CHANNELS-1);
  signal fifo_dout_tready    : type_tready(0 to NUM_CHANNELS-1);

  signal decim_dout_tdata     : type_tdata(0 to NUM_CHANNELS-1);
  signal decim_dout_tvalid    : type_tvalid(0 to NUM_CHANNELS-1);
  signal decim_dout_tlast     : type_tlast(0 to NUM_CHANNELS-1);
  signal decim_dout_tuser     : type_tuser(0 to NUM_CHANNELS-1);
  signal decim_dout_tstrb     : type_tstrb(0 to NUM_CHANNELS-1);
  signal decim_dout_tready    : type_tready(0 to NUM_CHANNELS-1);

  signal pbuf_mux_dout_tdata     : type_tdata(0 to NUM_CHANNELS-1);
  signal pbuf_mux_dout_tvalid    : type_tvalid(0 to NUM_CHANNELS-1);
  signal pbuf_mux_dout_tlast     : type_tlast(0 to NUM_CHANNELS-1);
  signal pbuf_mux_dout_tuser     : type_tuser(0 to NUM_CHANNELS-1);
  signal pbuf_mux_dout_tstrb     : type_tstrb(0 to NUM_CHANNELS-1);
  signal pbuf_mux_dout_tready    : type_tready(0 to NUM_CHANNELS-1);




  
  
  
  
  
  signal dummy : std_logic;
  
  signal ifft_cnfg : axi_stream16 := axis16_init;  
  signal ifft_status : axi_stream8 := axis8_init;
  
type tb_axi32 is record
    mybus : axi_stream32;
    q : std_logic_vector(15 downto 0);
    i : std_logic_vector(15 downto 0);
    hsv: std_logic;
end record tb_axi32;

-- prototype declaration, 31-16 into Q, 15 to 0 in I
--signal_tb <= (signal,signal.tdata(31 downto 16),signal.tdata(15 downto 0),signal.tvalid and signal.tready);
  
  signal oi_dout_test, pktbuf_dout_test, fft_dout_test, mixer_dout_test, fifo_dout_test, mult_dout_test, decim_dout_test, ifft_dout_test, sbt_dout_test : tb_axi32;
  
  -- Event signals
  signal fft_event_frame_started         : std_logic := '0';
  signal fft_event_tlast_unexpected      : std_logic := '0';
  signal fft_event_tlast_missing         : std_logic := '0';
  signal fft_event_data_in_channel_halt  : std_logic := '0';
  signal fft_event_data_out_channel_halt  : std_logic := '0';
  signal fft_event_status_channel_halt  : std_logic := '0';
  -- Event signals
  signal ifft_event_frame_started         : std_logic := '0';
  signal ifft_event_tlast_unexpected      : std_logic := '0';
  signal ifft_event_tlast_missing         : std_logic := '0';
  signal ifft_event_data_in_channel_halt  : std_logic := '0';
  signal ifft_event_data_out_channel_halt  : std_logic := '0';
  signal ifft_event_status_channel_halt  : std_logic := '0';
  
  --constant n_fft: integer := 32;
  --signal log2_n : std_logic_vector(7 downto 0) := x"05";
  -- Forward FFT is N -> log2(N)
  signal log2_n : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( f_log2(Nfft) , 8) ); 
  
  -- Inverse FFT is N/D -> log2(N/D)
  signal log2_n_over_d : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( f_log2(Nfft/DECIMATE) , 8) ); 
  
  signal fwd_inv : std_logic := '1';
  signal fft_sc_sch :std_logic_vector(11 downto 0);
  signal fft_sc_sch_ext : std_logic_vector(14 downto 0);
  
  signal ifft_sc_sch :std_logic_vector(11 downto 0);
  signal ifft_sc_sch_ext : std_logic_vector(14 downto 0);
  
  signal fft_config_done :std_logic := '0';
  signal fft_config_done_dly1 :std_logic := '0';
  signal fft_config_done_dly2 :std_logic := '0';
  
  signal ifft_config_done :std_logic := '0';
  signal ifft_config_done_dly1 :std_logic := '0';
  signal ifft_config_done_dly2 :std_logic := '0';

  signal fft_once_per_frame : std_logic;
  signal ifft_once_per_frame : std_logic;
  
  type blk_exp_ram_t is array (0 to 7) of std_logic_vector(4 downto 0);
  signal blk_exp_ram : blk_exp_ram_t;
  
  signal blk_exp_in: std_logic_vector(4 downto 0);
  

  signal oi_s_tready :std_logic := '0';
  signal oi_s_tvalid :std_logic := '0';
  
  signal oi_m_tfirst : std_logic := '0';
  signal aresetn_oi : std_logic := '0';
  
  --signal rom_addr : std_logic_vector(31 downto 0) := (others=>'0');
  --signal rom_data : std_logic_vector(31 downto 0) := (others=>'0');
  --signal rom_last_addr : std_logic := '0';
  --signal rom_last_data : std_logic := '0';
  
  signal axis_data_count_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal axis_wr_data_count_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal axis_rd_data_count_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
  
  signal internal_m_axis_data_tlast : std_logic;
  
 
  constant cmpy_bg : integer := 1;

  signal cmpy_shift : integer range 0 to Nfft;

  -- Register Controls

  signal status_register, control_register : register_array;

  --attribute mark_debug of control_register : signal is "true";

  signal reset_register : std_logic_vector(31 downto 0);
  signal reset_oi, reset_pkt_buf, reset_fft, reset_fft_rearrange, reset_rom_multiply, reset_data_fifo, reset_stack_add, reset_ifft, reset_ds : std_logic;
  

  signal oi_n, oi_p, oi_nmp : std_logic_vector(15 downto 0);
  signal oi_samples_in, oi_samples_out : std_logic_vector(31 downto 0);
  signal oi_run : std_logic;

  signal fr_pktlen : std_logic_vector(15 downto 0);

  type bins_array_type is array (0 to NUM_CHANNELS) of std_logic_vector(15 downto 0);
  signal fr_bins : bins_array_type;
  
  signal rm_samples_in, rm_samples_out : std_logic_vector(31 downto 0);

  signal sa_pktlen_in, sa_pktlen_out, sa_pktlen_ratio  : std_logic_vector(31 downto 0);

  

  signal fft_tuser : std_logic_vector(15 downto 0);

  signal ds_n, ds_p : std_logic_vector(15 downto 0);

  signal oi_fifo_status, rm_fifo_status, ds_fifo_status : std_logic_vector(7 downto 0);

  signal internal_s_axis_data_tready :std_logic := '0';
  
  
  type ss_array32 is array (0 to NUM_CHANNELS) of std_logic_vector(31 downto 0);
  type fs_array8 is array (0 to NUM_CHANNELS) of std_logic_vector(7 downto 0);
  
  signal fr_samples_in, fr_samples_out, sa_samples_in, sa_samples_out, axis_data_count_2, axis_wr_data_count_2, axis_rd_data_count_2, axis_data_count_3, axis_wr_data_count_3, axis_rd_data_count_3  : ss_array32;
  signal fr_fifo_status, sa_fifo_status : fs_array8;
  
  
begin



fft_sc_sch <= x"AAA";
fft_sc_sch_ext <= "000" & fft_sc_sch;
-- scaled option: fft_cnfg.tdata <= fft_sc_sch_ext & fwd_inv & log2_n;
-- w/ block fp, we don't provide scaling schedule, and tdata is 9 bits padded to 16
fft_cnfg.tdata <= x"0" & "000" & fwd_inv & log2_n;
fft_cnfg.tvalid <= '1';

ifft_sc_sch <= x"000";
ifft_sc_sch_ext <= "000" & ifft_sc_sch;
-- scaled option: ifft_cnfg.tdata <= ifft_sc_sch_ext & (not fwd_inv) & log2_n;
ifft_cnfg.tdata <= x"0" & "000"  & (not fwd_inv) & log2_n_over_d;
 
ifft_cnfg.tvalid <= '1';

---------------------------------------------------------
-- FFT Core Configuration logic
---------------------------------------------------------

cfng_fft_proc:process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            --aresetn_oi <= '0';
            fft_config_done <= '0';
            ifft_config_done <= '0';
        else
            fft_config_done_dly1 <= fft_config_done;
            fft_config_done_dly2 <= fft_config_done_dly1;
            
            ifft_config_done_dly1 <= ifft_config_done;
            ifft_config_done_dly2 <= ifft_config_done_dly1;
            
            if fft_config_done = '0' then
                --wait for tready
                --s_axis_data_tready <= '0';
                if fft_cnfg.tready = '1' then
                    fft_config_done <= '1';
                end if;
            end if;
            
            if ifft_config_done = '0' then
                --wait for tready
                --s_axis_data_tready <= '0';
                if ifft_cnfg.tready = '1' then
                    ifft_config_done <= '1';
                end if;
            end if;
            
            
            if ((fft_config_done_dly2 = '1') AND (ifft_config_done_dly2 = '1')) then
                --aresetn_oi <= '1';
            end if;
        end if;
    end if;
end process;

-- Switch upside ready on FFT is configured -- This is just an AND gate idiot.
--s_axis_data_tready <= '1' when oi_s_tready = '1' and fft_config_done_dly2 = '1' else '0';
--
--oi_s_tvalid <= s_axis_data_tvalid when fft_config_done_dly2 = '1' else '0';

dbg_axis_in.tdata <= s_axis_data_tdata;
dbg_axis_in.tvalid <= s_axis_data_tvalid;
dbg_axis_in.tready <= internal_s_axis_data_tready;
dbg_axis_in.tuser(15 downto 0) <= s_axis_data_tuser(15 downto 0);


s_axis_data_tready <= internal_s_axis_data_tready;

---------------------------------------------------------
-- Overlap Inputs Logic
--
-- This data needs to be spaced on the input so that the 
-- output rate is supported. For input at X MSamp/sec,
-- the output rate is X*(N/(N-P+1))
-- AXIS solves this, in that it will push back on the upstream
-- to support whatever the output rate is; but it doesn't allieviate
-- the need for the output rate to be greater, and actually all processing
-- from here to the discard_samples block to run at N/(N-P+1) * the sample rate
-- for example w/ N=1024, and P=257, all this logic has to run at 4/3 the sample rate
---------------------------------------------------------

-------------------------
-- AXI Slave address 0x04
-------------------------

axis_overlap_inputs_inst : axis_overlap_inputs
  generic map (
    RAMDEPTH => Nfft,
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32
    )
  PORT MAP (
    s_axis_aclk => aclk,
    s_axis_aresetn  => reset_oi,    
    --s_axis_tvalid => oi_s_tvalid,
    --s_axis_tready => oi_s_tready,       
    s_axis_tvalid => s_axis_data_tvalid,
    s_axis_tready => internal_s_axis_data_tready, 
    s_axis_tdata => s_axis_data_tdata,
    s_axis_tuser => s_axis_data_tuser,
    s_axis_tstrb=> (others=> '0'),
    s_axis_tlast=> '0',
    
    m_axis_aclk => aclk,
    m_axis_aresetn  => reset_oi,  
    m_axis_tvalid => oi_dout.tvalid,
    m_axis_tready => oi_dout.tready,
    m_axis_tlast => oi_dout.tlast,
    m_axis_tuser => oi_dout.tuser(15 downto 0),
    m_axis_tdata => oi_dout.tdata,    
    m_axis_tstrb=> open,

    run         => oi_run,
    n           => oi_n,
    p           => oi_p, 
    n_minus_p   => oi_nmp,

    fifo_status => oi_fifo_status,
    samples_in => oi_samples_in,
    samples_out=> oi_samples_out


  );
-----------------
-- Test Signal --
-----------------
oi_dout_test <= (oi_dout,oi_dout.tdata(31 downto 16),oi_dout.tdata(15 downto 0),oi_dout.tvalid and oi_dout.tready);

-- This packet buffer ensures that only entire frames get ingested by the FFT. The rational for this
-- need is, briefly, that if the input stalls mid-frame, the processing and output stages stall as well

oi_pktbuf_inst : axis_packet_buffer
  PORT MAP (
    s_axis_aresetn => reset_pkt_buf,
    s_axis_aclk    => aclk,
    
    s_axis_tdata     => oi_dout.tdata,
    s_axis_tvalid    => oi_dout.tvalid,
    s_axis_tready    => oi_dout.tready,
    s_axis_tlast     => oi_dout.tlast,
    s_axis_tuser     => oi_dout.tuser(15 downto 0),
    
    m_axis_tvalid => pktbuf_dout.tvalid,
    m_axis_tready => pktbuf_dout.tready,
    m_axis_tdata => pktbuf_dout.tdata,
    m_axis_tlast => pktbuf_dout.tlast,
    m_axis_tuser => pktbuf_dout.tuser(15 downto 0),
    
    axis_data_count => axis_data_count_1,
    axis_wr_data_count => axis_wr_data_count_1,
    axis_rd_data_count => axis_rd_data_count_1
  );

pktbuf_dout_test <= (pktbuf_dout,pktbuf_dout.tdata(31 downto 16),pktbuf_dout.tdata(15 downto 0),pktbuf_dout.tvalid and pktbuf_dout.tready);

---------------------------------------------------------
-- Forward FFT
-----------------------------------------------


fft_inst : xfft_0
    PORT MAP (
      aclk => aclk,
      aclken => '1',
      aresetn => reset_fft,
      s_axis_config_tdata => fft_cnfg.tdata,
      s_axis_config_tvalid =>fft_cnfg.tvalid,
      s_axis_config_tready => fft_cnfg.tready,
      
      s_axis_data_tdata     => pktbuf_dout.tdata,
      s_axis_data_tvalid    => pktbuf_dout.tvalid,
      s_axis_data_tready    => pktbuf_dout.tready,
      s_axis_data_tlast     => pktbuf_dout.tlast,
      
      m_axis_data_tdata     => fft_dout.tdata,
      m_axis_data_tuser     => fft_dout.tuser,
      m_axis_data_tvalid    => fft_dout.tvalid,
      m_axis_data_tlast     => fft_dout.tlast,
      m_axis_data_tready     => fft_dout.tready,
      
      m_axis_status_tdata     => fft_status.tdata,
      m_axis_status_tvalid    => fft_status.tvalid,
      m_axis_status_tready     => fft_status.tready,
      
      event_frame_started           => fft_event_frame_started,
      event_tlast_unexpected        => fft_event_tlast_unexpected,
      event_tlast_missing           => fft_event_tlast_missing,
      event_data_in_channel_halt    => fft_event_data_in_channel_halt,
      event_data_out_channel_halt   => fft_event_data_out_channel_halt,
      event_status_channel_halt     => fft_event_status_channel_halt
    );
    
fft_status.tready <= '1';

-----------------
-- Test Signal --
-----------------
fft_dout_test <= (fft_dout,fft_dout.tdata(31 downto 16),fft_dout.tdata(15 downto 0),fft_dout.tvalid and fft_dout.tready);
fft_tuser <= "000000" & fft_dout.tuser(9 downto 0);



-----------------------------------------------
-- Fanout
-----------------------------------------------
axis_fanout_inst : axis_fanout
  generic map (
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32,
    NUM_MASTERS => NUM_CHANNELS
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,
 
    -- This is a single AXI-Stream
    s_axis_tvalid => fft_dout.tvalid,
    s_axis_tready => fft_dout.tready,
    s_axis_tdata => fft_dout.tdata,
    s_axis_tuser=>  fft_dout.tuser,
    s_axis_tstrb=>  "0000",
    s_axis_tlast=> fft_dout.tlast,
    
    -- This is 4 AXI-streams
    -- These are all vectors of the appropriate Type
    m_axis_tvalid => fanout_tvalid,
    m_axis_tready => fanout_tready,
    m_axis_tlast => fanout_tlast,
    m_axis_tdata => fanout_tdata,    
    m_axis_tstrb=> fanout_tstrb
  );

gen_fft_rearrange: for i in 0 to 3 generate

-------------------------------------------------------
-- Frequency Domain Mixing
------------------------------------------------------

--Instantiate axis_fft_rearrange here on FFT output

    axis_fft_rearrange_inst : axis_fft_rearrange
      generic map (
        RAMDEPTH => Nfft,
        C_M_AXIS_TDATA_WIDTH=> 32,
        C_M_AXIS_TUSER_WIDTH=> 16,
        C_S_AXIS_TDATA_WIDTH=> 32
        )
      PORT MAP (
        -- Ports of Axi Slave Bus Interface S00_AXIS
        s_axis_aclk => aclk,
        s_axis_aresetn  => reset_fft_rearrange,    
        s_axis_tvalid => fanout_tvalid(i),
        s_axis_tready => fanout_tready(i),         --this is an out to upstream
        s_axis_tdata => fanout_tdata(i),
        s_axis_tstrb=> "0000",
        s_axis_tlast=> fanout_tlast(i),
        
        m_axis_tvalid => mixer_dout_tvalid(i),
        m_axis_tready => mixer_dout_tready(i),
        m_axis_tlast => mixer_dout_tlast(i),
        m_axis_tdata => mixer_dout_tdata(i),
        m_axis_tuser => mixer_dout_tuser(i)(15 downto 0),    
        m_axis_tstrb=> open,

        pktlen => fr_pktlen,
        bins => fr_bins(i),

        fifo_status => fr_fifo_status(i),
        samples_in => fr_samples_in(i),
        samples_out=> fr_samples_out(i)
      );


end generate;

-----------------
-- Test Signal --
-----------------
--mixer_dout_test <= (mixer_dout,mixer_dout.tdata(31 downto 16),mixer_dout.tdata(15 downto 0),mixer_dout.tvalid and mixer_dout.tready);

  axis_mulit_ram_multiply_inst : axis_multi_ram_multiply
    generic map (
      Nfft => Nfft,
      filter_file => filter_file,
      C_M_AXIS_TDATA_WIDTH=> 32,
      C_M_AXIS_TUSER_WIDTH=> 24,
      C_S_AXIS_TDATA_WIDTH=> 32,
      C_S_AXIS_TUSER_WIDTH=> 24,
      NUM_CHANS => 4
      )
    PORT MAP (
      -- Ports of Axi Slave Bus Interface S00_AXIS
      s_axis_aclk => aclk,
      s_axis_aresetn  => reset_rom_multiply,    
      s_axis_tvalid => mixer_dout_tvalid,
      s_axis_tready => mixer_dout_tready,         
      s_axis_tdata => mixer_dout_tdata,
      s_axis_tuser => mixer_dout_tuser,
      s_axis_tstrb=> ("0000","0000","0000","0000"),
      s_axis_tlast=> mixer_dout_tlast,
      
      m_axis_tvalid => mult_dout_tvalid,
      m_axis_tready => mult_dout_tready,
      m_axis_tlast => mult_dout_tlast,
      m_axis_tdata => mult_dout_tdata, 
      m_axis_tuser => mult_dout_tuser,   
      m_axis_tstrb=> open,
  
      samples_in      => rm_samples_in,
      samples_out     => rm_samples_out,
      
      rc_axi_aclk     => aclk,
      rc_axi_aresetn  => reset_rom_multiply, 
      rc_axi_awaddr   => rc_axi_awaddr,
      rc_axi_awprot   => rc_axi_awprot,
      rc_axi_awvalid  => rc_axi_awvalid,
      rc_axi_awready  => rc_axi_awready,
      rc_axi_wdata    => rc_axi_wdata,
      rc_axi_wstrb    => rc_axi_wstrb,
      rc_axi_wvalid   => rc_axi_wvalid,
      rc_axi_wready   => rc_axi_wready,
      rc_axi_bresp    => rc_axi_bresp,
      rc_axi_bvalid   => rc_axi_bvalid,
      rc_axi_bready   => rc_axi_bready,
      rc_axi_araddr   => rc_axi_araddr,
      rc_axi_arprot   => rc_axi_arprot,
      rc_axi_arvalid  => rc_axi_arvalid,
      rc_axi_arready  => rc_axi_arready,
      rc_axi_rdata    => rc_axi_rdata,
      rc_axi_rresp    => rc_axi_rresp,
      rc_axi_rvalid   => rc_axi_rvalid,
      rc_axi_rready   => rc_axi_rready,

      fifo_status => rm_fifo_status
    );
  
--mult_dout_test <= (mult_dout,mult_dout.tdata(31 downto 16),mult_dout.tdata(15 downto 0),mult_dout.tvalid and mult_dout.tready);
 ---------------------------------------------------------
 -- AXI-Stream Data Fifo
 -- Because after accepting the first input sample of the very first transform operation
 -- Xilinx' FFT Core Might drop TREADY for a single clock cycle
 -- Despite supposedly being "Real Time". THIS IS SO GD ANNOYING.
 -- It forces you to use the AXI-Stream 2-way handshake (tvalid and tready)
 -- on the upstream side of the FFT, which forces one to design for
 -- 2-way flow control.
 -- Drop in this Fifo and ensure that the downstream NEVER blocks deeper
 -- than it's depth. Garbage.

 -- This fifo provides 16 samples worth of elasticity. I think
 -- if I wanted to use this to deal with the lack of TREADY on the
 -- mult and ROM, I could expand this to some size, large enough
 -- that it would "never" overflow in practice. That'd be poor.
 ---------------------------------------------------------

gen_stack_add: for i in 0 to 3 generate

 
    fifo_instance : axis_data_fifo_32_x16
       PORT MAP (
         s_axis_aresetn => reset_data_fifo,
         s_axis_aclk => aclk,
         s_axis_tvalid => mult_dout_tvalid(i),
         s_axis_tready => mult_dout_tready(i),
         s_axis_tdata => mult_dout_tdata(i),
         s_axis_tuser => mult_dout_tuser(i),
         s_axis_tlast => mult_dout_tlast(i),
         m_axis_tvalid => fifo_dout_tvalid(i),
         m_axis_tready => fifo_dout_tready(i),
         m_axis_tdata => fifo_dout_tdata(i),
         m_axis_tuser => fifo_dout_tuser(i),
         m_axis_tlast => fifo_dout_tlast(i),
         axis_data_count => axis_data_count_2(i),
         axis_wr_data_count => axis_wr_data_count_2(i),
         axis_rd_data_count => axis_rd_data_count_2(i)
       );
    
    
    
    -----------------
    -- Test Signal --
    -----------------
    --fifo_dout_test <= (fifo_dout,fifo_dout.tdata(31 downto 16),fifo_dout.tdata(15 downto 0),fifo_dout.tvalid and fifo_dout.tready);
    -------------------------------------------------------
    -- Frequency Domain Decimation
    ------------------------------------------------------
    
    axis_stack_add_inst : axis_stack_add
      generic map (
        RAMDEPTH => Nfft,
        C_M_AXIS_TDATA_WIDTH=> 32,
        C_M_AXIS_TUSER_WIDTH=> 16,
        C_S_AXIS_TDATA_WIDTH=> 32
        )
      PORT MAP (
        -- Ports of Axi Slave Bus Interface S00_AXIS
        s_axis_aclk => aclk,
        s_axis_aresetn  => reset_stack_add,    
        s_axis_tvalid => fifo_dout_tvalid(i),
        s_axis_tready => fifo_dout_tready(i),         --this is an out to upstream
        s_axis_tdata => fifo_dout_tdata(i),
        s_axis_tstrb=> (others=>'0'),
        s_axis_tlast=> fifo_dout_tlast(i),
        
        m_axis_tvalid => decim_dout_tvalid(i),
        m_axis_tready => decim_dout_tready(i),
        m_axis_tlast => decim_dout_tlast(i),
        m_axis_tdata => decim_dout_tdata(i),    
        m_axis_tstrb=> open,
        m_axis_tuser => decim_dout_tuser(i),
    
        pktlen_in       => sa_pktlen_in, -- Drive all 4 with the same signals
        pktlen_out      => sa_pktlen_out,
        pktlen_ratio    => sa_pktlen_ratio,
    
        samples_in      => sa_samples_in(i),
        samples_out     => sa_samples_out(i),
    
        fifo_status => sa_fifo_status(i)
      );
    
    interleave_pktbuf_inst : axis_packet_buffer
      PORT MAP (
        s_axis_aresetn => reset_pkt_buf,
        s_axis_aclk    => aclk,
        
        s_axis_tdata     => decim_dout_tdata(i),
        s_axis_tvalid    => decim_dout_tvalid(i),
        s_axis_tready    => decim_dout_tready(i),
        s_axis_tlast     => decim_dout_tlast(i),
        s_axis_tuser     => decim_dout_tuser(i),
        
        m_axis_tvalid => pbuf_mux_dout_tvalid(i),
        m_axis_tready => pbuf_mux_dout_tready(i),
        m_axis_tdata => pbuf_mux_dout_tdata(i),
        m_axis_tlast => pbuf_mux_dout_tlast(i),
        m_axis_tuser => pbuf_mux_dout_tuser(i),
        
        axis_data_count => axis_data_count_3(i),
        axis_wr_data_count => axis_wr_data_count_3(i),
        axis_rd_data_count => axis_rd_data_count_3(i)
      );

end generate;




axis_packet_mux_inst : axis_packet_mux
  generic map (
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32,
    NUM_SLAVES => NUM_CHANNELS
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,
 
    -- This is 4 AXI-streams
    -- These are all vectors of the appropriate Type
    s_axis_tvalid => pbuf_mux_dout_tvalid,
    s_axis_tready => pbuf_mux_dout_tready,
    s_axis_tdata => pbuf_mux_dout_tdata,
    s_axis_tuser=>  pbuf_mux_dout_tuser,
    s_axis_tstrb=>  pbuf_mux_dout_tstrb,
    s_axis_tlast=> pbuf_mux_dout_tlast,
    
    -- This is a single AXI-Stream
    m_axis_tvalid => decim_dout.tvalid,
    m_axis_tready => decim_dout.tready,
    m_axis_tlast => decim_dout.tlast,
    m_axis_tdata => decim_dout.tdata,    
    m_axis_tstrb=> open
  );
                    
-----------------
-- Test Signal --
-----------------
--decim_dout_test <= (decim_dout,decim_dout.tdata(31 downto 16),decim_dout.tdata(15 downto 0),decim_dout.tvalid and decim_dout.tready);


   
---------------------------------------------------------
-- Inverse FFT Core
---------------------------------------------------------
   
ifft_inst : xfft_0
     PORT MAP (
       aclk => aclk,
       aclken => '1',
       aresetn => reset_ifft,
       s_axis_config_tdata  => ifft_cnfg.tdata,
       s_axis_config_tvalid =>ifft_cnfg.tvalid,
       s_axis_config_tready => ifft_cnfg.tready,

       s_axis_data_tdata    => decim_dout.tdata,
       s_axis_data_tvalid   => decim_dout.tvalid,
       s_axis_data_tready   => decim_dout.tready,  -- This is an output to upstream
       s_axis_data_tlast    => decim_dout.tlast,

       m_axis_data_tdata    => ifft_dout.tdata,
       m_axis_data_tuser    => ifft_dout.tuser,
       m_axis_data_tvalid   => ifft_dout.tvalid,
       m_axis_data_tlast    => ifft_dout.tlast,
       m_axis_data_tready    => ifft_dout.tready,

       m_axis_status_tdata     => ifft_status.tdata,
       m_axis_status_tvalid    => ifft_status.tvalid,
       m_axis_status_tready     => ifft_status.tready,

       event_frame_started          => ifft_event_frame_started,
       event_tlast_unexpected       => ifft_event_tlast_unexpected,
       event_tlast_missing          => ifft_event_tlast_missing,
       event_data_in_channel_halt    => ifft_event_data_in_channel_halt,
       event_data_out_channel_halt   => ifft_event_data_out_channel_halt,
       event_status_channel_halt     => ifft_event_status_channel_halt
     );

ifft_status.tready <= '1';

--ifft_xk_index <= ifft_dout.tuser(11 downto 0);
--ifft_blk_exp  <= ifft_dout.tuser(20 downto 16);   

-----------------
-- Test Signal --
-----------------
ifft_dout_test <= (ifft_dout,ifft_dout.tdata(31 downto 16),ifft_dout.tdata(15 downto 0),ifft_dout.tvalid and ifft_dout.tready);

axis_discard_samples_inst : axis_discard_samples
  generic map (
    --Nfft => Nfft/DECIMATE,
    --P => P/DECIMATE,
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => reset_ds,    
    s_axis_tvalid => ifft_dout.tvalid,
    s_axis_tready => ifft_dout.tready,         --this is an out to upstream
    s_axis_tdata => ifft_dout.tdata,
    s_axis_tuser => ifft_dout.tuser(15 downto 0),
    s_axis_tstrb=> (others=>'0'),
    s_axis_tlast=> ifft_dout.tlast,
    
    m_axis_tvalid => sbt_dout.tvalid,
    m_axis_tready => sbt_dout.tready,
    m_axis_tlast => sbt_dout.tlast,
    m_axis_tdata => sbt_dout.tdata, 
    m_axis_tuser => sbt_dout.tuser(15 downto 0),   
    m_axis_tstrb=> open,

    N => ds_n,
    P => ds_p,

    fifo_status => ds_fifo_status
  );

--axis_packet_mux_inst : axis_packet_demux
--  generic map (
--    C_M_AXIS_TDATA_WIDTH=> 32,
--    C_M_AXIS_TUSER_WIDTH=> 16,
--    C_S_AXIS_TDATA_WIDTH=> 32,
--    NUM_MASTERS => NUM_CHANNELS
--    )
--  PORT MAP (
--    -- Ports of Axi Slave Bus Interface S00_AXIS
--    s_axis_aclk => aclk,
--    s_axis_aresetn  => aresetn,
-- 
--    -- This is a single AXI-Stream
--    s_axis_tvalid => sbt_dout.tvalid,
--    s_axis_tready => sbt_dout.tready,
--    s_axis_tdata => sbt_dout.tdata,
--    s_axis_tuser=>  sbt_dout.tuser,
--    s_axis_tstrb=>  "0000",
--    s_axis_tlast=> sbt_dout.tlast,
--    
--    -- This is 4 AXI-streams
--    -- These are all vectors of the appropriate Type
--    m_axis_tvalid => m_axis _tvalid,
--    m_axis_tready => m_axis _tready,
--    m_axis_tlast => m_axis _tlast,
--    m_axis_tdata => m_axis _tdata,    
--    m_axis_tstrb=> m_axis _tstrb
--  );
  






-----------------
-- Test Signal --
-----------------
sbt_dout_test <= (sbt_dout,sbt_dout.tdata(31 downto 16),sbt_dout.tdata(15 downto 0),sbt_dout.tvalid and sbt_dout.tready);
 
 m_axis_data_tvalid <= sbt_dout.tvalid;
 sbt_dout.tready <= m_axis_data_tready;
 m_axis_data_tdata <= sbt_dout.tdata;
 m_axis_data_tlast <= sbt_dout.tlast;
 m_axis_data_tuser <= sbt_dout.tuser(15 downto 0);

-----------------------------------------
-- Control Interface
-----------------------------------------

axi_lite_inst : axi_lite64
	generic map (
        C_S_AXI_DATA_WIDTH	=> 32,
        C_S_AXI_ADDR_WIDTH	=> 8
	)
	port map (
        S_AXI_ACLK      => aclk,
        S_AXI_ARESETN   => aresetn, 

        -- Write address (issued by master, acceped by Slave)
        S_AXI_AWADDR    =>reg_s_axi_AWADDR ,
        S_AXI_AWPROT    =>reg_s_axi_AWPROT ,
        S_AXI_AWVALID   =>reg_s_axi_AWVALID,
        S_AXI_AWREADY   =>reg_s_axi_AWREADY,
        S_AXI_WDATA     =>reg_s_axi_WDATA  ,
        S_AXI_WSTRB     =>reg_s_axi_WSTRB  ,
        S_AXI_WVALID    =>reg_s_axi_WVALID ,
        S_AXI_WREADY    =>reg_s_axi_WREADY ,
        S_AXI_BRESP     =>reg_s_axi_BRESP  ,
        S_AXI_BVALID    =>reg_s_axi_BVALID ,
        S_AXI_BREADY    =>reg_s_axi_BREADY ,
        S_AXI_ARADDR    =>reg_s_axi_ARADDR ,
        S_AXI_ARPROT    =>reg_s_axi_ARPROT ,
        S_AXI_ARVALID   =>reg_s_axi_ARVALID,
        S_AXI_ARREADY   =>reg_s_axi_ARREADY,
        S_AXI_RDATA     =>reg_s_axi_RDATA  ,
        S_AXI_RRESP     =>reg_s_axi_RRESP  ,
        S_AXI_RVALID    =>reg_s_axi_RVALID ,
        S_AXI_RREADY    =>reg_s_axi_RREADY ,
        
        registers_out_to_logic  => control_register,
        registers_in_to_bus     => status_register
	);

-- see axidma-socket-fd/files/register_addresses.h
-------------------------------
-- Status (CPU read-only) Registers
-------------------------------

status_register(0) <= x"DEADBEEF";       --0x00

status_register(4)  <= oi_fifo_status;
status_register(5)  <= oi_samples_in;
status_register(6)  <= oi_samples_out;

---status_register(8)  <= FFT;

status_register(7) <= axis_data_count_1;
status_register(8) <= axis_wr_data_count_1;
status_register(9) <= axis_rd_data_count_1;


status_register(12)  <= fr_fifo_status(0);
status_register(13)  <= fr_samples_in(0);
status_register(14)  <= fr_samples_out(0);

status_register(16)  <= rm_fifo_status;
status_register(17)  <= rm_samples_in;
status_register(18)  <= rm_samples_out;

status_register(20)  <= sa_fifo_status(0);
status_register(21)  <= sa_samples_in(0);
status_register(22)  <= sa_samples_out(0);

--status_register(24)  <= IFFT;

status_register(23) <= axis_data_count_2(0);
status_register(24) <= axis_wr_data_count_2(0);
status_register(25) <= axis_rd_data_count_2(0);

status_register(28)  <= ds_fifo_status;

-------------------------------
-- Control (CPU read-write) Registers
-------------------------------

-----------------------------
-- Resets, ctrl word 0x0,0d0,
-----------------------------
-- to get to Byte address, multiply word by 4 and add 0x80

reset_register  <= control_register(0)(31 downto 0); --0x80

---------------------------
-- Overlap Inputs, ctrl word addr: 0x04(0d4), byte addr = 0x10 + 0x80 = 0x90
---------------------------
oi_n            <= control_register(4)(15 downto 0); --0x90
oi_p            <= control_register(5)(15 downto 0); --0x94
oi_nmp          <= control_register(6)(15 downto 0); --0x98
oi_run          <= control_register(7)(0);

---------------------------
-- FFT           , ctrl word addr: 0x08(0d8)
---------------------------
log2_n          <= control_register(8)(7 downto 0); --0xA0

---------------------------
-- FFT Rearrange , ctrl word addr: 0x0C (0d12)
---------------------------
fr_pktlen       <= control_register(12)(15 downto 0); --0xB0
fr_bins(0)         <= control_register(13)(15 downto 0); --0xB4
fr_bins(1)         <= control_register(13)(31 downto 16);
fr_bins(2)         <= control_register(14)(15 downto 0);
fr_bins(3)         <= control_register(14)(31 downto 16);

---------------------------
-- RAM Multiply , ctrl word addr: 0x10 (0d16)
---------------------------

---------------------------
-- Stack Add     , ctrl word addr: 0x14 (0d20)
---------------------------
sa_pktlen_in    <= control_register(20)(31 downto 0); --0xD0
sa_pktlen_out   <= control_register(21)(31 downto 0); --0xD4
sa_pktlen_ratio <= control_register(22)(31 downto 0); --0xD8

---------------------------
-- IFFT          , ctrl word addr: 0x18 (0d24)
---------------------------
log2_n_over_d          <= control_register(24)(7 downto 0); --0xE0
---------------------------
-- Discard Samples, ctrl word addr: 0x1C (0d28)
---------------------------
ds_n                   <= control_register(28)(15 downto 0);
ds_p                   <= control_register(29)(15 downto 0);

---------------------------
-- Discrete control signals
---------------------------

--Resets are active low
-- Both AH => OR
-- Both AL => AND
-- A AL and B AH => A AND NOT B
reset_oi            <= aresetn and not reset_register(0);  --ctrl 0 is reg 32, byte 128 address => 0x80
reset_pkt_buf       <= aresetn and not reset_register(1);  
reset_fft           <= aresetn and not reset_register(2);
reset_fft_rearrange <= aresetn and not reset_register(3);
reset_rom_multiply  <= aresetn and not reset_register(4);
reset_data_fifo     <= aresetn and not reset_register(5);
reset_stack_add     <= aresetn and not reset_register(6);
reset_ifft          <= aresetn and not reset_register(7);
reset_ds            <= aresetn and not reset_register(8);








end structural;
