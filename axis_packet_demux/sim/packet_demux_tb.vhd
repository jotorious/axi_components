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
use work.axis_packet_mux_pkg.all;

entity packet_demux_tb is
--  Port ( );
end packet_demux_tb;

architecture testbed of packet_demux_tb is

component axis_packet_demux
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 16;
        NUM_MASTERS               : integer   := 4
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser    : in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
        s_axis_tstrb	: in std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out type_tvalid(0 to NUM_MASTERS-1);
		m_axis_tdata	: out type_tdata(0 to NUM_MASTERS-1);
		m_axis_tstrb	: out type_tstrb(0 to NUM_MASTERS-1);
        m_axis_tuser	: out type_tuser(0 to NUM_MASTERS-1);
		m_axis_tlast	: out type_tlast(0 to NUM_MASTERS-1);
		m_axis_tready	: in type_tready(0 to NUM_MASTERS-1)

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

  constant NUM_OUTPUTS : integer := 4;


  --Output Signals
  signal tb_out_re, tb_out_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn                     : std_logic := '0';  -- synchronous active low reset
  signal aclken                      : std_logic := '0';  -- clock enable to DDS

  --file outfile : text open write_mode is "Needle_SBT.txt";

  type integer_array is array (0 to NUM_OUTPUTS -1) of integer;
  signal s_written, s_delta : integer_array;
  signal s_read : integer;

  signal m_axis_tdata : type_tdata(0 to NUM_OUTPUTS-1);
  signal m_axis_tvalid: type_tvalid(0 to NUM_OUTPUTS-1);
  signal m_axis_tlast: type_tlast(0 to NUM_OUTPUTS-1);
  signal m_axis_tuser: type_tuser(0 to NUM_OUTPUTS-1);
  signal m_axis_tstrb: type_tstrb(0 to NUM_OUTPUTS-1);
  signal m_axis_tready: type_tready(0 to NUM_OUTPUTS-1);

  type fname_arr is array (0 to NUM_OUTPUTS -1) of string(1 to 4);
  constant fnames : fname_arr := ("tdo0","tdo1","tdo2","tdo3");



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
            PKTLEN => 64,
            infname => "testramp",
            CPS => 1
        )
        port map (
            M_AXIS_ACLK => aclk,
            M_AXIS_ARESETN => aresetn,
            M_AXIS_TVALID => testin.tvalid,
            M_AXIS_TDATA  => testin.tdata,
            M_AXIS_TUSER  => testin.tuser,
            M_AXIS_TREADY => testin.tready,
            M_AXIS_TLAST  => testin.tlast,
            M_AXIS_TSTRB => open,
            samples_read => s_read
        );



axis_packet_mux_inst : axis_packet_demux
  generic map (
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32,
    NUM_MASTERS => NUM_OUTPUTS
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,
 
    -- This is a single AXI-Stream
    s_axis_tvalid => testin.tvalid,
    s_axis_tready => testin.tready,
    s_axis_tdata => testin.tdata,
    s_axis_tuser=>  testin.tuser,
    s_axis_tstrb=>  "0000",
    s_axis_tlast=> testin.tlast,
    
    -- This is 4 AXI-streams
    -- These are all vectors of the appropriate Type
    m_axis_tvalid => m_axis_tvalid,
    m_axis_tready => m_axis_tready,
    m_axis_tlast => m_axis_tlast,
    m_axis_tdata => m_axis_tdata,    
    m_axis_tstrb=> m_axis_tstrb
  );
  
tb_axis_sink_instances: for i in 0 to 3 generate

    s_axis_tb_inst : s_axis_sink
        generic map(
            PKTLEN => 64,
            outfname => fnames(i),
            CPS => 1
        )
        port map (
            S_AXIS_ACLK => aclk,
            S_AXIS_ARESETN => aresetn,
            S_AXIS_TVALID => m_axis_tvalid(i),
            S_AXIS_TDATA => m_axis_tdata(i),
            S_AXIS_TUSER => m_axis_tuser(i),
            S_AXIS_TREADY => m_axis_tready(i),
            S_AXIS_TLAST => m_axis_tlast(i),
            S_AXIS_TSTRB => m_axis_tstrb(i),
            samples_written => s_written(i)
        );
end generate;

end testbed;
