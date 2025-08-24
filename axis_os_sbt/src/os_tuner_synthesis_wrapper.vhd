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

entity os_tuner_synthesis_wrapper is
--  Port ( );
end os_tuner_synthesis_wrapper;

architecture wrapper of os_tuner_synthesis_wrapper is

component os_tuner
    generic (
        Nfft : integer ;
        P    : integer ;

        DECIMATE : integer ;
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
        reg_s_axi_RREADY	: in std_logic;
        
        --rc_axi_aclk    : IN STD_LOGIC;
        --rc_axi_aresetn : IN STD_LOGIC;
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

type axi_stream32 is record
    tdata : std_logic_vector(31 downto 0);
    tuser : std_logic_vector(15 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream32;

signal testin : axi_stream32;
signal testout : axi_stream32;

type axi_lite is record
    AWADDR	:  std_logic_vector(7 downto 0);
	AWPROT	:  std_logic_vector(2 downto 0);
	AWVALID	:  std_logic;
	AWREADY	: std_logic;
	WDATA	: std_logic_vector(31 downto 0);
	WSTRB	: std_logic_vector(3 downto 0);
	WVALID	: std_logic;
	WREADY	: std_logic;
	BRESP	: std_logic_vector(1 downto 0);
	BVALID	: std_logic;
	BREADY	: std_logic;
	ARADDR	: std_logic_vector(7 downto 0);
	ARPROT	: std_logic_vector(2 downto 0);
	ARVALID	: std_logic;
	ARREADY	: std_logic;
	RDATA	: std_logic_vector(31 downto 0);
	RRESP	: std_logic_vector(1 downto 0);
	RVALID	: std_logic;
	RREADY	: std_logic;
end record axi_lite;


signal testreg : axi_lite;

type axi_lite2 is record
    AWADDR	:  std_logic_vector(12 downto 0);
	AWPROT	:  std_logic_vector(2 downto 0);
	AWVALID	:  std_logic;
	AWREADY	: std_logic;
	WDATA	: std_logic_vector(31 downto 0);
	WSTRB	: std_logic_vector(3 downto 0);
	WVALID	: std_logic;
	WREADY	: std_logic;
	BRESP	: std_logic_vector(1 downto 0);
	BVALID	: std_logic;
	BREADY	: std_logic;
	ARADDR	: std_logic_vector(12 downto 0);
	ARPROT	: std_logic_vector(2 downto 0);
	ARVALID	: std_logic;
	ARREADY	: std_logic;
	RDATA	: std_logic_vector(31 downto 0);
	RRESP	: std_logic_vector(1 downto 0);
	RVALID	: std_logic;
	RREADY	: std_logic;
end record axi_lite2;


signal testreg2 : axi_lite2;


    -- General signals
signal aclk                        : std_logic := '0';  -- the master clock
signal aresetn                     : std_logic := '0';  -- synchronous active low reset

attribute keep : string;
attribute keep of testin : signal is "true";
attribute keep of testout : signal is "true";
attribute keep of testreg : signal is "true";



  -----------------------------------------------------------------------
  -- Provide Generics
  -----------------------------------------------------------------------
  
  constant Nfft : integer := 1024;
  constant P : integer := 256;
  --constant D : integer := 16;
  --constant filter_filename : string := "fco_0625_p_257_n_1024.data";

  constant D : integer := 4;
  --constant filter_filename : string := "fco_25_p_257_n_1024.data";
  constant filter_filename : string := "filter25_257_1024_14.data";

begin



os_tuner_inst : os_tuner
  generic map (
    Nfft => Nfft,
    P => P,
    DECIMATE => D,
    filter_file => filter_filename
  )
  port map (
    aresetn => aresetn,
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
    reg_s_axi_RREADY    =>testreg.RREADY,

    rc_axi_AWADDR    =>testreg2.AWADDR ,
    rc_axi_AWPROT    =>testreg2.AWPROT ,
    rc_axi_AWVALID   =>testreg2.AWVALID,
    rc_axi_AWREADY   =>testreg2.AWREADY,
    rc_axi_WDATA     =>testreg2.WDATA  ,
    rc_axi_WSTRB     =>testreg2.WSTRB  ,
    rc_axi_WVALID    =>testreg2.WVALID ,
    rc_axi_WREADY    =>testreg2.WREADY ,
    rc_axi_BRESP     =>testreg2.BRESP  ,
    rc_axi_BVALID    =>testreg2.BVALID ,
    rc_axi_BREADY    =>testreg2.BREADY ,
    rc_axi_ARADDR    =>testreg2.ARADDR ,
    rc_axi_ARPROT    =>testreg2.ARPROT ,
    rc_axi_ARVALID   =>testreg2.ARVALID,
    rc_axi_ARREADY   =>testreg2.ARREADY,
    rc_axi_RDATA     =>testreg2.RDATA  ,
    rc_axi_RRESP     =>testreg2.RRESP  ,
    rc_axi_RVALID    =>testreg2.RVALID ,
    rc_axi_RREADY    =>testreg2.RREADY


  );





end wrapper;
