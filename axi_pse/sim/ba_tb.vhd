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

entity ba_tb is
--  Port ( );
end ba_tb;

architecture testbed of ba_tb is

component block_averager
	generic(
        RAMDEPTH : integer := 256
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_rdy : out std_logic;
        din_last : in std_logic;
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic;
        dout_rdy : in std_logic;
        dout_index : out std_logic_vector(15 downto 0);

        pktlen_in : in std_logic_vector(31 downto 0);
        frames_out : in std_logic_vector(31 downto 0);
        pkts_to_ave : in std_logic_vector(31 downto 0);

        counter_in : out std_logic_vector(31 downto 0);
        counter_out: out std_logic_vector(31 downto 0)

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
  
  constant TEST_PKTLENIN : integer := 16;
  constant TEST_PKTLENOUT : integer := 16;

  --Output Signals
  signal tb_out_re, tb_out_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn                     : std_logic := '0';  -- synchronous active low reset
  signal aclken                      : std_logic := '0';  -- clock enable to DDS

  --file outfile : text open write_mode is "Needle_SBT.txt";

  signal s_read, s_written, s_delta : integer;

  signal s_frames_in : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(TEST_PKTLENIN,32));
  signal s_frames_out : std_logic_vector(31 downto 0) := x"00000001";
  signal s_frames_ratio : std_logic_vector(31 downto 0) := x"00000004";

  signal s_counter_in : std_logic_vector(31 downto 0) ;
  signal s_counter_out : std_logic_vector(31 downto 0) ;

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

m_axis_tb_inst : m_axis_source
    generic map(
        PKTLEN => TEST_PKTLENIN,
        PKTS_TO_SOURCE => 512,
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

DUT: block_averager 
	generic map(
        RAMDEPTH => 32
		)
	port map(
        clk	=> aclk,
		rst	=> aresetn,
		din	        => testin.tdata,
		din_en      => testin.tvalid,
        din_rdy     => testin.tready,
        din_last    => testin.tlast,
		
        dout        => testout.tdata,
		dout_en     => testout.tvalid,
        dout_last   => testout.tlast,
        dout_rdy    => '1',

        pktlen_in   => s_frames_in,
        frames_out  => s_frames_out,
        pkts_to_ave => s_frames_ratio,

        counter_in => s_counter_in,
        counter_out=> s_counter_out
    );



  

s_axis_tb_inst : s_axis_sink
    generic map(
        PKTLEN => TEST_PKTLENOUT,
        outfname => "testdata.out",
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


end testbed;
