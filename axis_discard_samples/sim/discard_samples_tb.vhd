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

entity discard_samples_tb is
--  Port ( );
end discard_samples_tb;

architecture testbed of discard_samples_tb is

component axis_discard_samples
    generic (
        Nfft : integer := 32;
       P    : integer := 8;
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer   := 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic
	);
end component;



type axi_stream32 is record
    tdata : std_logic_vector(31 downto 0);
    tuser : std_logic_vector(15 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream32;

signal testin : axi_stream32;
signal testout : axi_stream32;


-----------------------------------------------------------------------
  -- Timing constants
  -----------------------------------------------------------------------
  constant CLOCK_PERIOD : time := 10 ns;
  --constant T_HOLD       : time := 10 ns;
  --constant T_STROBE     : time := CLOCK_PERIOD - (1 ns);

  -----------------------------------------------------------------------
  -- DUT signals
  -----------------------------------------------------------------------
  
  constant TEST_PKTLEN : integer := 64;

  --Output Signals
  signal tb_xk_re, tb_xk_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn                     : std_logic := '0';  -- synchronous active low reset
  signal aclken                      : std_logic := '0';  -- clock enable to DDS

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
		aresetn <= '0';
		wait for 6*CLOCK_PERIOD;
		aresetn <= '1';
		wait;
end process;

m_axis_source_inst : m_axis_source
    generic map(
        PKTLEN => TEST_PKTLEN,
        infname => "testramp",
        CPS => 1
    )
    port map (
        M_AXIS_ACLK => aclk,
        M_AXIS_ARESETN => aresetn,
        M_AXIS_TVALID => testin.tvalid,
        M_AXIS_TDATA => testin.tdata,
        M_AXIS_TREADY => testin.tready,
        M_AXIS_TLAST => testin.tlast,
        M_AXIS_TSTRB => open,
        samples_read => s_read
    );

axis_discard_samples_inst : axis_discard_samples
  generic map (
    Nfft => 64,
    P => 16,
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,    
    s_axis_tvalid => testin.tvalid,
    s_axis_tready => testin.tready,         --this is an out to upstream
    s_axis_tdata => testin.tdata,
    s_axis_tstrb=> (others=>'0'),
    s_axis_tlast=> testin.tlast,
    
    m_axis_tvalid => testout.tvalid,
    m_axis_tready => testout.tready,
    m_axis_tlast => testout.tlast,
    m_axis_tdata => testout.tdata, 
    m_axis_tuser => testout.tuser,   
    m_axis_tstrb=> open
  );
  

s_axis_sink_inst : s_axis_sink
    generic map(
        PKTLEN => TEST_PKTLEN,
        outfname => "testdata.out",
        CPS => 4
    )
    port map (
        S_AXIS_ACLK => aclk,
        S_AXIS_ARESETN => aresetn,
        S_AXIS_TVALID => testout.tvalid,
        S_AXIS_TDATA => testout.tdata,
        S_AXIS_TREADY => testout.tready,
        S_AXIS_TLAST => testout.tlast,
        S_AXIS_TSTRB => "0000",
        samples_written => s_written
    );

s_delta <= s_read - s_written;

tb_xk_re <= testout.tdata(15 downto 0);
tb_xk_im <= testout.tdata(31 downto 16);


end testbed;
