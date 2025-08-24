library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use ieee.std_logic_textio.all;  
library std;
use STD.textio.all;

use work.axis_tb_package.all;

entity verifytb_tb is
--  Port ( );
end verifytb_tb;

architecture testbed of verifytb_tb is


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
        M_AXIS_TUSER => testin.tuser,
        M_AXIS_TREADY => testin.tready,
        M_AXIS_TLAST => testin.tlast,
        M_AXIS_TSTRB => open,
        samples_read => s_read
    );


testout.tdata <= testin.tdata;
testout.tuser <= testin.tuser;
testout.tlast <= testin.tlast;
testout.tvalid <= testin.tvalid;
testin.tready <= testout.tready;

s_axis_verifysink_inst : s_axis_verifysink
    generic map(
        PKTLEN => TEST_PKTLEN,
        outfname => "testdata.out",
        verfname => "testramp",
        CPS => 1
    )
    port map (
        S_AXIS_ACLK => aclk,
        S_AXIS_ARESETN => aresetn,
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


end testbed;
