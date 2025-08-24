-- ***************************************************************************
-- 03/29/2019
-- Joe McKinney
-- BIT Systems

-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;

-- Entity Declaration ********************************************************

entity axis_mag_squared is
	generic (
        -- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer   := 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
    port(
        s_axis_aclk : IN STD_LOGIC;
        s_axis_aresetn : IN STD_LOGIC;
        
        -- AXI-Stream Slave (Input) Interface
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata : in std_logic_vector(31 downto 0);
        s_axis_tlast : in std_logic;
        s_axis_tuser : in std_logic_vector(15 downto 0);
        
        -- AXI-Stream Master (Output) Interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tdata : out std_logic_vector(31 downto 0);
        m_axis_tlast : out std_logic;
        m_axis_tuser : out std_logic_vector(15 downto 0)
		);
end axis_mag_squared;

architecture behav of axis_mag_squared is

component mag_squared is
	port(
		clk : IN STD_LOGIC;
        rstn : IN STD_LOGIC;
        
        din : in std_logic_vector(31 downto 0);
        din_en : in std_logic;
        din_last : in std_logic;
        din_user : in std_logic_vector(15 downto 0);
        
        dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(15 downto 0);
        dout : out std_logic_vector(31 downto 0)
		);
end component;



signal din : std_logic_vector(31 downto 0);
signal din_user: std_logic_vector(15 downto 0);
signal din_en: std_logic;
signal din_last: std_logic;

signal u_fifo_empty, u_fifo_al_empty, u_fifo_rden : std_logic;
    
signal dout: std_logic_vector(31 downto 0);
signal dout_user: std_logic_vector(15 downto 0);
signal dout_en :std_logic;
signal dout_last: std_logic;

signal d_fifo_full, d_fifo_almost_full: std_logic;

begin

-- Instantiation of Axi Bus Interface S00_AXIS
axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,
        C_S_AXIS_TUSER_WIDTH	=> C_M_AXIS_TUSER_WIDTH,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_EMPTY => 3
	)
	port map (
	    dout => din,
        dout_last => din_last,
        dout_user => din_user,
        fifo_rden =>u_fifo_rden,
        fifo_empty => u_fifo_empty,
        fifo_almost_empty => u_fifo_al_empty,
	
		S_AXIS_ACLK	=> s_axis_aclk,
		S_AXIS_ARESETN	=> s_axis_aresetn,
		S_AXIS_TREADY	=> s_axis_tready,
		S_AXIS_TDATA	=> s_axis_tdata,
		S_AXIS_TUSER	=> s_axis_tuser,
        S_AXIS_TSTRB	=> "0000",
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);

mag_squared_inst: mag_squared
    port map (
        clk     => s_axis_aclk,
        rstn    => s_axis_aresetn,
        din   => din,
        din_last   => din_last,
        din_user => din_user,
        din_en  => din_en,
        dout_en => dout_en,
        dout    => dout,
        dout_last => dout_last,
        dout_user => dout_user
        ); 

-- Instantiation of Axi Bus Interface M00_AXIS
axis_wrapper_maxis_inst : axis_wrapper_maxis
    generic map (
        C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
        C_M_AXIS_TUSER_WIDTH    => C_M_AXIS_TUSER_WIDTH,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_FULL => 4
    )
    port map (
        din => dout,
        din_en =>dout_en,
        din_user => dout_user,
        din_last => dout_last,
        fifo_full => d_fifo_full,
        fifo_almost_Full => d_fifo_almost_full,
            
        M_AXIS_ACLK    => s_axis_aclk,
        M_AXIS_ARESETN    => s_axis_aresetn,
        M_AXIS_TVALID    => m_axis_tvalid,
        M_AXIS_TDATA    => m_axis_tdata,
        M_AXIS_TUSER    => m_axis_tuser,
        M_AXIS_TSTRB    => open,
        M_AXIS_TLAST    => m_axis_tlast,
        M_AXIS_TREADY    => m_axis_tready
    );

--u_fifo_rden <= not d_fifo_full;
u_fifo_rden <= not d_fifo_almost_full;

din_en <= u_fifo_rden and not u_fifo_empty;

end architecture;

