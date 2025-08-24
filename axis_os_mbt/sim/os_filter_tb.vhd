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

entity os_filter_tb is
--  Port ( );
end os_filter_tb;

architecture Testbed of os_filter_tb is

component m_axis_tb
    generic (
        PKTLEN : integer;
        infname: string
    );
    port (
-- Global ports
		M_AXIS_ACLK	: in std_logic;
		-- 
		M_AXIS_ARESETN	: in std_logic;
		-- Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
		M_AXIS_TVALID	: out std_logic;
		-- TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		M_AXIS_TDATA	: out std_logic_vector(31 downto 0);
		-- TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		M_AXIS_TSTRB	: out std_logic_vector(3 downto 0);
		-- TLAST indicates the boundary of a packet.
		M_AXIS_TLAST	: out std_logic;
		-- TREADY indicates that the slave can accept a transfer in the current cycle.
		M_AXIS_TREADY	: in std_logic
    );
end component;

component s_axis_tb
    generic (
        PKTLEN : integer;
        outfname : string
    );
    port (
-- Global ports
		S_AXIS_ACLK	: in std_logic;
		-- 
		S_AXIS_ARESETN	: in std_logic;
		-- Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
		S_AXIS_TVALID	: in std_logic;
		-- TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		S_AXIS_TDATA	: in std_logic_vector(31 downto 0);
		-- TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		S_AXIS_TSTRB	: in std_logic_vector(3 downto 0);
		-- TLAST indicates the boundary of a packet.
		S_AXIS_TLAST	: in std_logic;
		-- TREADY indicates that the slave can accept a transfer in the current cycle.
		S_AXIS_TREADY	: out std_logic
    );
end component;


component os_filter
    generic (
        Nfft : integer;
        P    : integer;
        filter_file : string
    );
    port (
        aclk : IN STD_LOGIC;
        aclken : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        
        s_axis_data_tvalid : in std_logic;
        s_axis_data_tready : out std_logic;
        s_axis_data_tdata : in std_logic_vector(31 downto 0);
        
        m_axis_data_tvalid : out std_logic;
        m_axis_data_tready : in std_logic;
        m_axis_data_tdata : out std_logic_vector(31 downto 0)
    );
end component;




COMPONENT axis_data_fifo_0
  PORT (
    s_axis_aresetn : IN STD_LOGIC;
    s_axis_aclk : IN STD_LOGIC;
    s_axis_aclken : IN STD_LOGIC;
    s_axis_tvalid : IN STD_LOGIC;
    s_axis_tready : OUT STD_LOGIC;
    s_axis_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_aclken : IN STD_LOGIC;
    m_axis_tvalid : OUT STD_LOGIC;
    m_axis_tready : IN STD_LOGIC;
    m_axis_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    axis_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    axis_wr_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    axis_rd_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;



type axi_stream32 is record
    tdata : std_logic_vector(31 downto 0);
    tuser : std_logic_vector(15 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream32;

signal testin : axi_stream32;
signal testout : axi_stream32;

type tb_axi32 is record
    mybus : axi_stream32;
    myimag : std_logic_vector(15 downto 0);
    myreal : std_logic_vector(15 downto 0);
end record tb_axi32;





-----------------------------------------------------------------------
  -- Timing constants
  -----------------------------------------------------------------------
  constant CLOCK_PERIOD : time := 10 ns;
  --constant T_HOLD       : time := 10 ns;
  --constant T_STROBE     : time := CLOCK_PERIOD - (1 ns);

  -----------------------------------------------------------------------
  -- DUT signals
  -----------------------------------------------------------------------
  
  constant Nfft : integer := 512;
  constant P : integer := 64;
  constant fname : string := "quarter_band_512";

  --Output Signals
  signal tb_xk_re, tb_xk_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn                     : std_logic := '0';  -- synchronous active low reset
  signal aclken                      : std_logic := '0';  -- clock enable to DDS

  file outfile : text open write_mode is "Needle_SBT.txt";

  signal tb_din : tb_axi32;
  signal tb_dout : tb_axi32;

begin

tb_din <= (testin,testin.tdata(31 downto 16),testin.tdata(15 downto 0));
tb_dout <= (testout,testout.tdata(31 downto 16),testout.tdata(15 downto 0));

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

m_axis_tb_inst : m_axis_tb
    generic map(
        PKTLEN => 8192,
        infname => "testgus"
    )
    port map (
        M_AXIS_ACLK => aclk,
        M_AXIS_ARESETN => aresetn,
        M_AXIS_TVALID => testin.tvalid,
        M_AXIS_TDATA => testin.tdata,
        M_AXIS_TREADY => testin.tready,
        M_AXIS_TLAST => testin.tlast,
        M_AXIS_TSTRB => open
    );

os_filter_inst : os_filter
  generic map (
    Nfft => Nfft,
    P => P,
    filter_file => fname
  )
  port map (
    aresetn => aresetn,
    aclk => aclk,
    aclken => aclken,
    
    s_axis_data_tvalid => testin.tvalid,
    s_axis_data_tready => testin.tready,         --this is an out to upstream
    s_axis_data_tdata => testin.tdata,
    
    m_axis_data_tvalid => testout.tvalid,
    m_axis_data_tready => testout.tready,
    m_axis_data_tdata => testout.tdata
  );

s_axis_tb_inst : s_axis_tb
    generic map(
        PKTLEN => 8192,
        outfname => "testdata.out"
    )
    port map (
        S_AXIS_ACLK => aclk,
        S_AXIS_ARESETN => aresetn,
        S_AXIS_TVALID => testout.tvalid,
        S_AXIS_TDATA => testout.tdata,
        S_AXIS_TREADY => testout.tready,
        S_AXIS_TLAST => testout.tlast,
        S_AXIS_TSTRB => "0000"
    );

tb_xk_re <= testout.tdata(15 downto 0);
tb_xk_im <= testout.tdata(31 downto 16);


end Testbed;
