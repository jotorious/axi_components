library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axis_wrapper_pkg.all;
entity axis_overlap_inputs is
	generic (
        RAMDEPTH : integer := 1024;
        C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
        -- This is the downstread or output interface
		m_axis_aclk	: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tvalid	: out std_logic;
		m_axis_tready	: in std_logic;
        m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		

		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tvalid	: in std_logic;
        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tuser	: in std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;

        run         : in std_logic;
        n_minus_p   : in std_logic_vector(15 downto 0);
        n           : in std_logic_vector(15 downto 0); 
        p           : in std_logic_vector(15 downto 0);

        fifo_status : out std_logic_vector(7 downto 0);
        samples_in  : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)
		
	);
end axis_overlap_inputs;

architecture arch_imp of axis_overlap_inputs is

component overlap_input_version3
	generic(
		RAMDEPTH : integer range 8 to 1024:= 1024
		);
	port(
		
        clk	: in std_logic;
		rst	: in std_logic;

        run : in std_logic;        
        n_minus_p : in std_logic_vector(15 downto 0); --768
        n : in std_logic_vector (15 downto 0); --1024
        p : in std_logic_vector (15 downto 0); --256
        
        din	: in  std_logic_vector(31 downto 0);
        din_vld : in std_logic;
        din_rdy : out std_logic;
        din_idx : in std_logic_vector(15 downto 0);
		
        dout	: out std_logic_vector(31 downto 0);
        dout_vld : out std_logic;
        dout_rdy : in std_logic;
        dout_idx : out std_logic_vector(15 downto 0);
        dout_last : out std_logic;

        samples_in : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)
		);
end component;

signal s_din : std_logic_vector(31 downto 0);
signal s_din_en: std_logic;
signal s_din_last: std_logic;
signal s_din_rdy: std_logic;
signal s_din_idx : std_logic_vector(15 downto 0);
    
signal s_dout: std_logic_vector(31 downto 0);
signal s_dout_en :std_logic;
signal s_dout_last: std_logic;
signal s_dout_user: std_logic_vector(15 downto 0);

signal d_fifo_full, u_fifo_empty, u_fifo_al_empty, u_fifo_rden : std_logic;

signal ds_not_af : std_logic;
signal d_fifo_almost_full : std_logic;

signal internal_fifo_status : std_logic_vector(7 downto 0);

begin


-- Instantiation of Axi Bus Interface S00_AXIS
axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,
        C_S_AXIS_TUSER_WIDTH	=> 16,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_EMPTY => 3
	)
	port map (
	    dout => s_din,
        dout_last => s_din_last,
        dout_user => s_din_idx,
        fifo_rden =>u_fifo_rden,
        fifo_empty => u_fifo_empty,
        fifo_almost_empty => u_fifo_al_empty,
	
		S_AXIS_ACLK	=> s_axis_aclk,
		S_AXIS_ARESETN	=> s_axis_aresetn,
		S_AXIS_TREADY	=> s_axis_tready,
		S_AXIS_TDATA	=> s_axis_tdata,
		S_AXIS_TUSER	=> s_axis_tuser,
        S_AXIS_TSTRB	=> s_axis_tstrb,
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);


	-- Add user logic here

overlap_input_inst: overlap_input_version3
        generic map(
            RAMDEPTH => RAMDEPTH)
        port map(
            
            clk    => s_axis_aclk,
            rst    => s_axis_aresetn,

            run             => run,            
            n_minus_p       => n_minus_p,
            n               => n,
            p               => p,

            din => s_din,
            din_vld => s_din_en,
            din_rdy => s_din_rdy,
            din_idx => s_din_idx,

            dout     => s_dout,
            dout_vld => s_dout_en,
            dout_rdy => ds_not_af,

            dout_idx => s_dout_user,
            dout_last => s_dout_last,

            samples_in => samples_in,
            samples_out=> samples_out
            );

	-- User logic ends
    
    -- Instantiation of Axi Bus Interface M00_AXIS
    axis_wrapper_maxis_inst : axis_wrapper_maxis
        generic map (
            C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
            C_M_AXIS_TUSER_WIDTH    => 16,
            FIFO_MAX_DEPTH => 8,
            FIFO_PROG_FULL => 5
        )
        port map (
            din => s_dout,
            din_en =>s_dout_en,
            din_last => s_dout_last,
            din_user => s_dout_user,
            fifo_full => d_fifo_full,
            fifo_almost_full => d_fifo_almost_full,
                
            M_AXIS_ACLK    => s_axis_aclk,
            M_AXIS_ARESETN    => s_axis_aresetn,
            M_AXIS_TVALID    => m_axis_tvalid,
            M_AXIS_TDATA    => m_axis_tdata,
            M_AXIS_TUSER    => m_axis_tuser,
            M_AXIS_TSTRB    => m_axis_tstrb,
            M_AXIS_TLAST    => m_axis_tlast,
            M_AXIS_TREADY    => m_axis_tready
        );

    --u_fifo_rden <= not d_fifo_full;
    ds_not_af <= not d_fifo_almost_full;
    u_fifo_rden <= ds_not_af and s_din_rdy;

    -- overlap_inputs generates it's own READY, and more importantly,
    -- doesn't accept data when it's own READY is low.
    s_din_en <= not u_fifo_empty;

    internal_fifo_status(0) <= u_fifo_empty;
    internal_fifo_status(1) <= u_fifo_al_empty;
    internal_fifo_status(2) <= u_fifo_rden;
    internal_fifo_status(3) <= s_din_en;

    internal_fifo_status(4) <= d_fifo_full;
    internal_fifo_status(5) <= d_fifo_almost_full;
    internal_fifo_status(6) <= s_dout_en;
    internal_fifo_status(7) <= ds_not_af;
    
    fifo_status <= internal_fifo_status;


end arch_imp;
