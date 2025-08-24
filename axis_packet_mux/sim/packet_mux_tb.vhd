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

entity packet_mux_tb is
--  Port ( );
end packet_mux_tb;

architecture testbed of packet_mux_tb is

component axis_packet_mux is
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer;
        C_M_AXIS_TUSER_WIDTH	: integer;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer;
        NUM_SLAVES               : integer
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

		s_axis_tready	: out type_tready(0 to NUM_SLAVES-1);
		s_axis_tdata	: in type_tdata(0 to NUM_SLAVES-1);
        s_axis_tuser    : in type_tuser(0 to NUM_SLAVES-1);
        s_axis_tstrb	: in type_tstrb(0 to NUM_SLAVES-1);
		s_axis_tlast	: in type_tlast(0 to NUM_SLAVES-1);
		s_axis_tvalid	: in type_tvalid(0 to NUM_SLAVES-1);

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic

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

  constant NUM_INPUTS : integer := 4;
  constant TB_PKTLEN : integer := 64 ; 
  constant TB_INPKTS : integer := 16;
  constant TB_OUTPKTS : integer := TB_INPKTS * NUM_INPUTS;


  -- The input file is a ramp on I, zeros on Q
  -- The output file has to be written to contain values appropriate
  -- for the above params.

    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn                     : std_logic := '0';  -- synchronous active low reset

  --file outfile : text open write_mode is "Needle_SBT.txt";

  type integer_array is array (0 to NUM_INPUTS-1) of integer;
  signal s_read, s_delta : integer_array;
  signal s_written : integer;

  constant cps_array : integer_array := (1,2,6,9);

  signal s_axis_tdata : type_tdata(0 to NUM_INPUTS-1);
  signal s_axis_tvalid: type_tvalid(0 to NUM_INPUTS-1);
  signal s_axis_tlast: type_tlast(0 to NUM_INPUTS-1);
  signal s_axis_tuser: type_tuser(0 to NUM_INPUTS-1);
  signal s_axis_tstrb: type_tstrb(0 to NUM_INPUTS-1);
  signal s_axis_tready: type_tready(0 to NUM_INPUTS-1);

  signal tb_done : boolean ;


begin

clk_proc: process
	begin
        if tb_done = FALSE then
		    wait for CLOCK_PERIOD/2;
		    aclk <= '1';
		    wait for CLOCK_PERIOD/2;
		    aclk <= '0';
        else
            wait;
        end if;
end process;

rst_proc: process
	begin
		wait for 4* CLOCK_PERIOD;
		aresetn <= '0';
		wait for 6*CLOCK_PERIOD;
		aresetn <= '1';
		wait;
end process;


tb_axis_source_instances: for i in 0 to NUM_INPUTS-1 generate

    m_axis_tb_inst : m_axis_source
        generic map(
            PKTLEN => TB_PKTLEN,
            PKTS_TO_SOURCE => TB_INPKTS,
            infname => "packetmuxin",
            CPS => cps_array(i)
        )
        port map (
            M_AXIS_ACLK => aclk,
            M_AXIS_ARESETN => aresetn,
            M_AXIS_TVALID => s_axis_tvalid(i),
            M_AXIS_TDATA  => s_axis_tdata(i),
            M_AXIS_TUSER  => s_axis_tuser(i),
            M_AXIS_TREADY => s_axis_tready(i),
            M_AXIS_TLAST  => s_axis_tlast(i),
            M_AXIS_TSTRB => s_axis_tstrb(i),
            samples_read => s_read(i)
        );

end generate;

axis_packet_mux_inst : axis_packet_mux
  generic map (
    C_M_AXIS_TDATA_WIDTH=> 32,
    C_M_AXIS_TUSER_WIDTH=> 16,
    C_S_AXIS_TDATA_WIDTH=> 32,
    NUM_SLAVES => NUM_INPUTS
    )
  PORT MAP (
    -- Ports of Axi Slave Bus Interface S00_AXIS
    s_axis_aclk => aclk,
    s_axis_aresetn  => aresetn,
 
    -- This is 4 AXI-streams
    -- These are all vectors of the appropriate Type
    s_axis_tvalid => s_axis_tvalid,
    s_axis_tready => s_axis_tready,
    s_axis_tdata => s_axis_tdata,
    s_axis_tuser=>  s_axis_tuser,
    s_axis_tstrb=>  s_axis_tstrb,
    s_axis_tlast=> s_axis_tlast,
    
    -- This is a single AXI-Stream
    m_axis_tvalid => testout.tvalid,
    m_axis_tready => testout.tready,
    m_axis_tlast => testout.tlast,
    m_axis_tdata => testout.tdata,    
    m_axis_tstrb=> open
  );
  
s_axis_tb_inst : s_axis_verifysink
    generic map(
        PKTLEN => TB_PKTLEN,
        PKTS_TO_SINK => TB_OUTPKTS,
        outfname => "testmuxout",
        verfname => "packetmuxout",
        CPS => 4
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
        samples_written => s_written,
        done => tb_done
    );

end testbed;
