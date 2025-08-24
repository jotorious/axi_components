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

entity os_tuner_tb is
--  Port ( );
end os_tuner_tb;

architecture Testbed of os_tuner_tb is

component axis_fifo
  generic (
    DWIDTH : integer :=  32;  -- FIFO data width
    FIFO_MAX_DEPTH : integer := 256;
    FIFO_PROG_FULL : integer := 252;
    FIFO_PROG_EMPTY: integer := 4
  );
  port (
    clk            : in std_logic;
    
    -- FIFO data input
    S_AXIS_TDATA   : in  std_logic_vector(DWIDTH-1 downto 0);
    S_AXIS_TVALID  : in  std_logic;
    S_AXIS_TREADY  : out std_logic := '0';

    -- FIFO data output
    M_AXIS_TDATA  : out std_logic_vector(DWIDTH-1 downto 0) := (others => '0');
    M_AXIS_TVALID : out std_logic := '0';
    M_AXIS_TREADY : in  std_logic
);
end component;

component os_tuner
    generic (
        Nfft : integer;
        P    : integer;

        DECIMATE : integer;

        filter_file: string
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
        reg_s_axi_RREADY	: in std_logic
    );
end component;

--type axi_stream32 is record
--    tdata : std_logic_vector(31 downto 0);
--    tuser : std_logic_vector(15 downto 0);
--    tvalid : std_logic;
--    tready : std_logic;
--    tlast  : std_logic;
--end record axi_stream32;



type tb_axi32 is record
    mybus : axi_stream32;
    q : std_logic_vector(15 downto 0);
    i : std_logic_vector(15 downto 0);
    hsv: std_logic;
end record tb_axi32;

signal tb_din : tb_axi32;
signal tb_dout, tb_dout2 : tb_axi32;

signal testin : axi_stream32;
signal testout : axi_stream32;
signal testout2 : axi_stream32;

signal testreg : axi_lite;



-----------------------------------------------------------------------
  -- Timing constants
  -----------------------------------------------------------------------
  constant CLOCK_PERIOD : time := 40 ns;
  --constant T_HOLD       : time := 10 ns;
  --constant T_STROBE     : time := CLOCK_PERIOD - (1 ns);

  -----------------------------------------------------------------------
  -- DUT signals
  -----------------------------------------------------------------------
  
  constant Nfft : integer := 1024;
  constant P : integer := 256;
  --constant D : integer := 16;
  --constant filter_filename : string := "fco_0625_p_257_n_1024.data";

  constant D : integer := 4;
  constant filter_filename : string := "fco_25_p_257_n_1024.data";


  --constant input_filename : string := "testsweep.ha";
  constant input_filename : string := "2mhz.ha";


  -- ROTATE MUST BE CONSTRAINED TO MULTIPLES OF V = N/P

  --Output Signals
  --signal tb_xk_re, tb_xk_im : std_logic_vector (15 downto 0);
  
    -- General signals
  signal aclk                        : std_logic := '0';  -- the master clock
  signal aresetn0, aresetn1,aresetn2 : std_logic := '0';  -- synchronous active low reset
  -- release reset in order DUT, register control, data source/sink



  file outfile : text open write_mode is "Needle_Testbed.txt";

  constant SOURCE_CPS : integer := 1;
  constant SINK_CPS : integer := 1;

  signal s_read, s_written, s_delta, s_delta_at_first_output : integer;
  signal s_ratio : real;


  constant sw_note : integer := 1024;
  signal sw_mod : integer := 0;
  signal sw_quo : integer := 0;

  signal frames : integer := 0;

begin

tb_din <= (testin,testin.tdata(31 downto 16),testin.tdata(15 downto 0),testin.tvalid and testin.tready);
tb_dout <= (testout,testout.tdata(31 downto 16),testout.tdata(15 downto 0),testout.tvalid and testout.tready);
tb_dout2 <= (testout2,testout2.tdata(31 downto 16),testout2.tdata(15 downto 0),testout2.tvalid and testout2.tready);

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
        PKTLEN => 768,
        infname => input_filename,
        CPS => SOURCE_CPS
    )
    port map (
        M_AXIS_ACLK => aclk,
        M_AXIS_ARESETN => aresetn2,
        M_AXIS_TVALID => testin.tvalid,
        M_AXIS_TDATA => testin.tdata,
        M_AXIS_TUSER => testin.tuser,
        M_AXIS_TREADY => testin.tready,
        M_AXIS_TLAST => testin.tlast,
        M_AXIS_TSTRB => open,
        samples_read => s_read
    );

os_tuner_inst : os_tuner
  generic map (
    Nfft => Nfft,
    P => P,

    DECIMATE => D,
    filter_file => filter_filename
  )
  port map (
    aresetn => aresetn0,
    aclk => aclk,
    
    s_axis_data_tvalid => testin.tvalid,
    s_axis_data_tready => testin.tready,
    s_axis_data_tdata => testin.tdata,
    s_axis_data_tlast => testin.tlast,
    s_axis_data_tuser => testin.tuser,
    
    m_axis_data_tvalid => testout.tvalid,
    m_axis_data_tready => testout.tready,
    m_axis_data_tdata => testout.tdata,
    m_axis_data_tlast => testout.tlast,
    m_axis_data_tuser => testout.tuser,
    
            -- Write address (issued by master, acceped by Slave)
    reg_s_axi_AWADDR    =>testreg.AWADDR ,
    reg_s_axi_AWPROT    =>testreg.AWPROT ,
    reg_s_axi_AWVALID   =>testreg.AWVALID,
    reg_s_axi_AWREADY   =>testreg.AWREADY,
    reg_s_axi_WDATA     =>testreg.WDATA  ,
    reg_s_axi_WSTRB     =>testreg.WSTRB  ,
    reg_s_axi_WVALID    =>testreg.WVALID ,
    reg_s_axi_WREADY    =>testreg.WREADY ,
    reg_s_axi_BRESP     =>testreg.BRESP  ,
    reg_s_axi_BVALID    =>testreg.BVALID ,
    reg_s_axi_BREADY    =>testreg.BREADY ,
    reg_s_axi_ARADDR    =>testreg.ARADDR ,
    reg_s_axi_ARPROT    =>testreg.ARPROT ,
    reg_s_axi_ARVALID   =>testreg.ARVALID,
    reg_s_axi_ARREADY   =>testreg.ARREADY,
    reg_s_axi_RDATA     =>testreg.RDATA  ,
    reg_s_axi_RRESP     =>testreg.RRESP  ,
    reg_s_axi_RVALID    =>testreg.RVALID ,
    reg_s_axi_RREADY    =>testreg.RREADY
    
  );

my_axis_fifo_inst:  axis_fifo
  generic map (
    DWIDTH =>  32,
    FIFO_MAX_DEPTH =>  256,
    FIFO_PROG_FULL =>  252,
    FIFO_PROG_EMPTY=>  4
  )
  port map(
    clk   => aclk,
    
    S_AXIS_TDATA  => testout.tdata,
    S_AXIS_TVALID  => testout.tvalid,
    S_AXIS_TREADY  => testout.tready,

    M_AXIS_TDATA    => testout2.tdata,
    M_AXIS_TVALID   => testout2.tvalid,
    M_AXIS_TREADY   => testout2.tready
);

s_axis_sink_inst : s_axis_sink
    generic map(
        PKTLEN => 8192,
        outfname => "testdata.out",
        CPS => SINK_CPS
    )
    port map (
        S_AXIS_ACLK => aclk,
        S_AXIS_ARESETN => aresetn2,
        S_AXIS_TVALID => testout2.tvalid,
        S_AXIS_TDATA => testout2.tdata,
        S_AXIS_TUSER => testout2.tuser,
        S_AXIS_TREADY => testout2.tready,
        S_AXIS_TLAST => testout2.tlast,
        S_AXIS_TSTRB => "0000",
        samples_written => s_written
    );

s_delta <= s_read - s_written;


test_proc: process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn0 = '0' then
            s_delta_at_first_output <= 0;
            sw_quo <= 0;
            sw_mod <= 0;
        elsif s_written = 1 then
            s_delta_at_first_output <= s_delta;
        else
            s_delta_at_first_output <= s_delta_at_first_output;
        end if;
        s_ratio <= (real(s_read )+ 0.001- real(s_delta_at_first_output))/(real(s_written)+0.001);
        
        sw_mod <= (s_written mod sw_note);
        sw_quo <= s_written / sw_note;

        if (sw_mod = 0) and not (sw_quo = 0) then
            report "Wrote " & integer'image(sw_quo*sw_note) & " samples to file";
        end if;

    end if;
end process;

--tb_xk_re <= testout.tdata(15 downto 0);
--tb_xk_im <= testout.tdata(31 downto 16);

    --Axi-lite Master
m_axi_lite_inst : m_axi_lite
	generic map (
		C_M_AXI_ADDR_WIDTH	=> 8,
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

end Testbed;
