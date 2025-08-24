library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;

entity axis_fft_rearrange is
	generic (
	   RAMDEPTH : integer := 32;
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
		s_axis_tvalid	: in std_logic;
        pktlen          : in std_logic_vector(15 downto 0);
        bins            : in std_logic_vector(15 downto 0);

        fifo_status : out std_logic_vector(7 downto 0);
        samples_in  : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)

	);
end axis_fft_rearrange;

architecture arch_imp of axis_fft_rearrange is

component packet_rearrange is
	generic(
		RAMDEPTH : integer
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
		din_rdy : out std_logic;
        dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_pkt_idx : out std_logic_vector(15 downto 0);
        dout_last : out std_logic;       
        dout_rdy : in std_logic;
        pktlen : in std_logic_vector(15 downto 0);
        bins : in std_logic_vector(15 downto 0);
        samples_in  : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)
		);
end component;

signal din : std_logic_vector(31 downto 0);
signal din_en: std_logic;
signal din_last: std_logic;
signal din_user : std_logic_vector(15 downto 0);
    
signal dout: std_logic_vector(31 downto 0);
signal dout_en :std_logic;
signal dout_last: std_logic;
signal dout_user : std_logic_vector(15 downto 0);

signal dout_pkt_idx: std_logic_vector(15 downto 0);

signal i_feedme : std_logic;


signal d_fifo_full, d_fifo_almost_full, u_fifo_empty, u_fifo_al_empty, u_fifo_rden, dout_vld, dout_rdy : std_logic;

signal d_not_almost_full : std_logic;

signal internal_fifo_status : std_logic_vector(7 downto 0);


--signal bins : std_logic_vector(15 downto 0);
--constant bins_integer : integer := 4;

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
		S_AXIS_TUSER	=> (others=> '0'),
        S_AXIS_TSTRB	=> s_axis_tstrb,
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);

--bins <= std_logic_vector(to_unsigned(bins_integer,bins'length));
	
packet_rearrange_inst: packet_rearrange
        generic map(
            RAMDEPTH => RAMDEPTH
            )
        port map(
            din => din,
            din_en => din_en,
            din_last => din_last,
            din_rdy => i_feedme,
            clk    => s_axis_aclk,
            rst    => s_axis_aresetn,
            dout => dout,
            dout_en => dout_en,
            dout_pkt_idx => dout_pkt_idx,
            dout_last => dout_last,
            dout_rdy => d_not_almost_full,

            pktlen => pktlen,
            bins => bins,

            samples_in => samples_in,
            samples_out=> samples_out
            );

	   d_not_almost_full <= not d_fifo_almost_full;
    
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
            din_user => dout_pkt_idx,
            din_last => dout_last,
            fifo_full => d_fifo_full,
            fifo_almost_Full => d_fifo_almost_full,
                
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
    ----u_fifo_rden <= not d_fifo_almost_full;
    u_fifo_rden <= i_feedme;

    din_en <= u_fifo_rden and not u_fifo_empty;

    internal_fifo_status(0) <= u_fifo_empty;
    internal_fifo_status(1) <= u_fifo_al_empty;
    internal_fifo_status(2) <= u_fifo_rden;
    internal_fifo_status(3) <= din_en;

    internal_fifo_status(4) <= d_fifo_full;
    internal_fifo_status(5) <= d_fifo_almost_full;
    internal_fifo_status(6) <= dout_en;
    internal_fifo_status(7) <= d_not_almost_full;
    
    fifo_status <= internal_fifo_status;


end arch_imp;
