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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use ieee.std_logic_textio.all;  
library std;
use STD.textio.all;

use work.axis_tb_package.all;

entity ram_multiply_tb is
--  Port ( );
end ram_multiply_tb;

architecture testbed of ram_multiply_tb is

component axis_ram_multiply
	generic (
	    Nfft : integer := 1024;
        filter_file: string    := "filter_coefs.data";
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer   := 24;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 24
	);
	port (
	
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser	: in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

        samples_in : out std_logic_vector(31 downto 0);
        samples_out: out std_logic_vector(31 downto 0);

        rc_axi_aclk    : IN STD_LOGIC;
        rc_axi_aresetn : IN STD_LOGIC;
        rc_axi_awaddr  : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
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
        rc_axi_araddr  : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
        rc_axi_arprot  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        rc_axi_arvalid : IN STD_LOGIC;
        rc_axi_arready : OUT STD_LOGIC;
        rc_axi_rdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        rc_axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        rc_axi_rvalid  : OUT STD_LOGIC;
        rc_axi_rready  : IN STD_LOGIC
	);
end component;



--type axi_stream32 is record
--    tdata : std_logic_vector(31 downto 0);
--    tuser : std_logic_vector(23 downto 0);
--    tvalid : std_logic;
--    tready : std_logic;
--    tlast  : std_logic;
--end record axi_stream32;

signal testin : axi_stream32;
signal testout : axi_stream32;

signal testreg : axi_lite_ram;

signal testin_tuser : std_logic_vector(23 downto 0);

signal testout_tuser : std_logic_vector(23 downto 0);


-----------------------------------------------------------------------
  -- Timing constants
  -----------------------------------------------------------------------
  constant CLOCK_PERIOD : time := 10 ns;
  --constant T_HOLD       : time := 10 ns;
  --constant T_STROBE     : time := CLOCK_PERIOD - (1 ns);

  -----------------------------------------------------------------------
  -- DUT signals
  -----------------------------------------------------------------------
  
  constant TEST_FFT : integer := 256;
  constant filter_filename : string := "filter_coefs.data";
  --constant filter_filename : string := "fco_0625_p_257_n_1024.data";

  --Output Signals
  signal tb_xk_re, tb_xk_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn0, aresetn1,aresetn2 : std_logic := '0';  -- synchronous active low reset
  -- release reset in order DUT, register control, data source/sink
  

  file outfile : text open write_mode is "Needle_SBT.txt";

  signal s_read, s_written, s_delta : integer;

begin

clk_proc: process
	begin
		wait for CLOCK_PERIOD/2;
		aclk <= '1';
		wait for CLOCK_PERIOD/2;
		aclk <= '0';
end process;

rst_proc: process
	begin
		wait for 4* CLOCK_PERIOD;
		aresetn0 <= '0';
        aresetn1 <= '0';
		wait for 12*CLOCK_PERIOD;
		aresetn0 <= '1';

        wait for 4*CLOCK_PERIOD;
        aresetn1 <= '1';

		wait;
end process;

m_axis_source_inst : m_axis_source
    generic map(
        PKTLEN => TEST_FFT,
        infname => "testramp",
        CPS => 1
    )
    port map (
        M_AXIS_ACLK => aclk,
        M_AXIS_ARESETN => aresetn2,
        M_AXIS_TVALID => testin.tvalid,
        M_AXIS_TDATA => testin.tdata,
        M_AXIS_TREADY => testin.tready,
        M_AXIS_TLAST => testin.tlast,
        M_AXIS_TUSER => testin.tuser(15 downto 0),
        samples_read => s_read
    );

testin_tuser(23 downto 16) <= (others=>'0');
testin_tuser(15 downto 0) <= testin.tuser(15 downto 0);

axis_ram_multiply_inst : axis_ram_multiply
  generic map (
    Nfft => TEST_FFT,
    filter_file => filter_filename,
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 24,
    C_S_AXIS_TDATA_WIDTH=> 32,
    C_S_AXIS_TUSER_WIDTH=> 24
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn0,    
    s_axis_tvalid => testin.tvalid,
    s_axis_tready => testin.tready,         --this is an out to upstream
    s_axis_tdata => testin.tdata,
    s_axis_tuser => testin_tuser,
    s_axis_tstrb=> "0000",
    s_axis_tlast=> testin.tlast,
    
    m_axis_tvalid => testout.tvalid,
    m_axis_tready => testout.tready,
    m_axis_tlast => testout.tlast,
    m_axis_tdata => testout.tdata, 
    m_axis_tuser => testout_tuser,   
    m_axis_tstrb=> open,

    rc_axi_aclk   => aclk,
    rc_axi_aresetn => aresetn0,
    rc_axi_AWADDR    =>testreg.AWADDR ,
    rc_axi_AWPROT    =>testreg.AWPROT ,
    rc_axi_AWVALID   =>testreg.AWVALID,
    rc_axi_AWREADY   =>testreg.AWREADY,
    rc_axi_WDATA     =>testreg.WDATA  ,
    rc_axi_WSTRB     =>testreg.WSTRB  ,
    rc_axi_WVALID    =>testreg.WVALID ,
    rc_axi_WREADY    =>testreg.WREADY ,
    rc_axi_BRESP     =>testreg.BRESP  ,
    rc_axi_BVALID    =>testreg.BVALID ,
    rc_axi_BREADY    =>testreg.BREADY ,
    rc_axi_ARADDR    =>testreg.ARADDR ,
    rc_axi_ARPROT    =>testreg.ARPROT ,
    rc_axi_ARVALID   =>testreg.ARVALID,
    rc_axi_ARREADY   =>testreg.ARREADY,
    rc_axi_RDATA     =>testreg.RDATA  ,
    rc_axi_RRESP     =>testreg.RRESP  ,
    rc_axi_RVALID    =>testreg.RVALID ,
    rc_axi_RREADY    =>testreg.RREADY



  );


testout.tuser <= testout_tuser(15 downto 0);

s_axis_sink_inst : s_axis_sink
    generic map(
        PKTLEN => TEST_FFT,
        outfname => "testdata.out",
        CPS => 8
    )
    port map (
        S_AXIS_ACLK => aclk,
        S_AXIS_ARESETN => aresetn2,
        S_AXIS_TVALID => testout.tvalid,
        S_AXIS_TDATA => testout.tdata,
        S_AXIS_TUSER => testout.tuser,
        S_AXIS_TREADY => testout.tready,
        S_AXIS_TLAST => testout.tlast,
        S_AXIS_TSTRB => "0000",
        samples_written => s_written
    );

s_delta <= s_read - s_written;

tb_xk_re <= testout.tdata(15 downto 0);
tb_xk_im <= testout.tdata(31 downto 16);

    --Axi-lite Master
m_axi_lite_inst : m_axi_lite_ram
	generic map (
		C_M_AXI_ADDR_WIDTH	=> 13,
		C_M_AXI_DATA_WIDTH	=> 32
	) port map (
		M_AXI_ACLK	    => aclk,
		M_AXI_ARESETN	=> aresetn1,
		
        M_AXI_AWADDR	    =>testreg.AWADDR,
		M_AXI_AWPROT		=>testreg.AWPROT,
		M_AXI_AWVALID		=>testreg.AWVALID,
		M_AXI_AWREADY		=>testreg.AWREADY,

		M_AXI_WDATA		    =>testreg.WDATA,
		M_AXI_WSTRB		    =>testreg.WSTRB,
		M_AXI_WVALID		=>testreg.WVALID,
		M_AXI_WREADY		=>testreg.WREADY,

		M_AXI_BRESP		    =>testreg.BRESP,
		M_AXI_BVALID		=>testreg.BVALID,
		M_AXI_BREADY		=>testreg.BREADY,

		M_AXI_ARADDR		=>testreg.ARADDR,
		M_AXI_ARPROT		=>testreg.ARPROT,
		M_AXI_ARVALID		=>testreg.ARVALID,
		M_AXI_ARREADY		=>testreg.ARREADY,

		M_AXI_RDATA		    =>testreg.RDATA,
		M_AXI_RRESP		    =>testreg.RRESP,
		M_AXI_RVALID		=>testreg.RVALID,
		M_AXI_RREADY		=>testreg.RREADY,
        done    => aresetn2
	);




end testbed;
