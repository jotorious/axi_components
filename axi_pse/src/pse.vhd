----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/12/2018 12:02:15 PM
-- Design Name: 
-- Module Name: pse.vhd
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


--- This is an Power Spectrum Estimator
-----------------------------------------------

-- Data Flow is as follows:

------------------

------------------
--      |
--      V



----------------------    -------------------------
-- Overlap P Inputs     RAM w/ window Coefs
----------------------    -------------------------
--      |                         |
--      V
--
--
--
--                                V
------------------------------------------
--         Complex Mult (Xilinx IP - AXIS)
------------------------------------------
--               |
--               V
------------------------------------------
--       FFT (Xilinx IP - AXIS)
------------------------------------------
--               |
--               V
------------------------------------------
--     Squarer ( Complex Mult)
------------------------------------------
--               |
--               V
------------------------------------------
--       Block Averager
------------------------------------------
--               |
--               V
------------------------------------------
--         Discard P Outputs
------------------------------------------
--               |
--               V

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;
use work.pse_pkg.all;
use work.axis_packet_mux_pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity pse is
    generic (
        MAX_NFFT : integer := 1024;
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
end pse;

architecture structural of pse is


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

  -- These all are still single streams
  signal dbg_axis_in : axi_stream32 := axis32_init;
  signal oi_dout : axi_stream32 := axis32_init;
  signal pktbuf_dout : axi_stream32 := axis32_init;
  signal mult_dout : axi_stream32 := axis32_init; 
  signal fft_dout : axi_stream32 := axis32_init;
  signal square_dout : axi_stream32 := axis32_init;
  signal avgr_dout : axi_stream32 := axis32_init;
  signal pse_dout : axi_stream32 := axis32_init;
  
  signal fft_cnfg : axi_stream16 := axis16_init;
  signal fft_status : axi_stream8 := axis8_init;
  signal mult_dout_dlong : std_logic_vector(63 downto 0);
  
  signal fft_cnfg : axi_stream16 := axis16_init;
  signal fft_status : axi_stream8 := axis8_init;
  signal mult_dout_dlong : std_logic_vector(63 downto 0);

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

  signal fr_pktlen, fr_bins : std_logic_vector(15 downto 0);

  signal rm_samples_in, rm_samples_out : std_logic_vector(31 downto 0);

  signal sa_pktlen_in, sa_pktlen_out, sa_pktlen_ratio  : std_logic_vector(31 downto 0);

  signal fft_tuser : std_logic_vector(15 downto 0);

  signal ds_n, ds_p : std_logic_vector(15 downto 0);

  signal oi_fifo_status, rm_fifo_status, ds_fifo_status : std_logic_vector(7 downto 0);

  signal internal_s_axis_data_tready :std_logic := '0';
  
  signal fr_samples_in, fr_samples_out, sa_samples_in, sa_samples_out, axis_data_count_2, axis_wr_data_count_2, axis_rd_data_count_2, axis_data_count_3, axis_wr_data_count_3, axis_rd_data_count_3  : ss_array32;
  signal fr_fifo_status, sa_fifo_status : fs_array8;
  
  
begin

fft_sc_sch <= x"AAA";
fft_sc_sch_ext <= "000" & fft_sc_sch;
-- scaled option: fft_cnfg.tdata <= fft_sc_sch_ext & fwd_inv & log2_n;
-- w/ block fp, we don't provide scaling schedule, and tdata is 9 bits padded to 16
fft_cnfg.tdata <= x"0" & "000" & fwd_inv & log2_n;
fft_cnfg.tvalid <= '1';

dbg_axis_in.tdata <= s_axis_data_tdata;
dbg_axis_in.tvalid <= s_axis_data_tvalid;
dbg_axis_in.tready <= internal_s_axis_data_tready;
dbg_axis_in.tuser(15 downto 0) <= s_axis_data_tuser(15 downto 0);

s_axis_data_tready <= internal_s_axis_data_tready;

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
--oi_dout_test <= (oi_dout,oi_dout.tdata(31 downto 16),oi_dout.tdata(15 downto 0),oi_dout.tvalid and oi_dout.tready);

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

--pktbuf_dout_test <= (pktbuf_dout,pktbuf_dout.tdata(31 downto 16),pktbuf_dout.tdata(15 downto 0),pktbuf_dout.tvalid and pktbuf_dout.tready);

  axis_ram_multiply_inst : axis_ram_multiply
    generic map (
      Nfft => Nfft,
      filter_file => filter_file,
      C_M_AXIS_TDATA_WIDTH=> 32,
      C_M_AXIS_TUSER_WIDTH=> 24,
      C_S_AXIS_TDATA_WIDTH=> 32,
      C_S_AXIS_TUSER_WIDTH=> 24
      )
    PORT MAP (
      -- Ports of Axi Slave Bus Interface S00_AXIS
      s_axis_aclk => aclk,
      s_axis_aresetn  => reset_rom_multiply,    
      s_axis_tvalid => pktbuf_dout.tvalid,
      s_axis_tready => pktbuf_dout.tready,         --this is an out to upstream
      s_axis_tdata => pktbuf_dout.tdata,
      s_axis_tuser => pktbuf_dout.tuser,
      s_axis_tstrb=> "0000",
      s_axis_tlast=> pktbuf_dout.tlast,
      
      m_axis_tvalid => mult_dout.tvalid,
      m_axis_tready => mult_dout.tready,
      m_axis_tlast => mult_dout.tlast,
      m_axis_tdata => mult_dout.tdata, 
      m_axis_tuser => mult_dout.tuser,   
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
      
      s_axis_data_tdata     => mult_dout.tdata,
      s_axis_data_tvalid    => mult_dout.tvalid,
      s_axis_data_tready    => mult_dout.tready,
      s_axis_data_tlast     => mult_dout.tlast,
      
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
--fft_dout_test <= (fft_dout,fft_dout.tdata(31 downto 16),fft_dout.tdata(15 downto 0),fft_dout.tvalid and fft_dout.tready);
fft_tuser <= "000000" & fft_dout.tuser(9 downto 0);


mag_squared_inst: axis_mag_squared
    generic map (
		C_M_AXIS_TDATA_WIDTH => 32,
        C_M_AXIS_TUSER_WIDTH => 16,
		C_S_AXIS_TDATA_WIDTH => 32
	);
    port map(
        s_axis_aclk =>
        s_axis_aresetn =>
        
        -- AXI-Stream Slave (Input) Interface
        s_axis_tvalid => fft_dout.tvalid,
        s_axis_tready => fft_dout.tready,
        s_axis_tdata =>  fft_dout.tdata,
        s_axis_tlast => fft_dout.tlast,
        s_axis_tuser => fft_dout.tuser,
        
        -- AXI-Stream Master (Output) Interface
        m_axis_tvalid => square_dout.tvalid,
        m_axis_tready => square_dout.tready,
        m_axis_tdata => square_dout.tdata,
        m_axis_tlast => square_dout.tlast,
        m_axis_tuser => square_dout.tuser,
		);



        

-----------------
-- Test Signal --
-----------------
--decim_dout_test <= (decim_dout,decim_dout.tdata(31 downto 16),decim_dout.tdata(15 downto 0),decim_dout.tvalid and decim_dout.tready);

axis_block_averager_inst : axis_block_averager
  generic map (
    RAMDEPTH => Nfft,
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,    
    s_axis_tvalid => square_dout.tvalid,
    s_axis_tready => square_dout.tready,         
    s_axis_tdata => square_dout.tdata,
    s_axis_tstrb=> "0000",
    s_axis_tlast=> square_dout.tlast,
    
    m_axis_tvalid => avgr_dout.tvalid,
    m_axis_tready => avgr_dout.tready,
    m_axis_tlast => avgr_dout.tlast,
    m_axis_tdata => avgr_dout.tdata,
    m_axis_tuser => avgr_dout.tuser,    
    m_axis_tstrb=> open,

    pktlen_in       => s_pktlen_in,
    pktlen_out      => s_pktlen_out,
    log2_pkts_to_ave    => s_pkts_to_aver,

    samples_in      => open,
    samples_out     => open,

    fifo_status => open

    
  );



-----------------
-- Test Signal --
-----------------
--sbt_dout_test <= (pse_dout,pse_dout.tdata(31 downto 16),pse_dout.tdata(15 downto 0),pse_dout.tvalid and pse_dout.tready);
 
 m_axis_data_tvalid <= avgr_dout.tvalid;
 avgr_dout.tready <= m_axis_data_tready;
 m_axis_data_tdata <= avgr_dout.tdata;
 m_axis_data_tlast <= avgr_dout.tlast;
 m_axis_data_tuser <= avgr_dout.tuser(15 downto 0);

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
