library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;

entity axis_ram_multiply is
	generic (
	    Nfft : integer := 1024;
        filter_file: string    := "filter_coefs.data";
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer   := 24;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 24
	);
	port (
	
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser	: in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

        samples_in : out std_logic_vector(31 downto 0);
        samples_out: out std_logic_vector(31 downto 0);

        rc_axi_aclk    : IN STD_LOGIC;
        rc_axi_aresetn : IN STD_LOGIC;
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
        rc_axi_rready  : IN STD_LOGIC;

        fifo_status : out std_logic_vector(7 downto 0)
	);
end axis_ram_multiply;

architecture arch_imp of axis_ram_multiply is

component ram_multiply
	generic(
        Nfft : integer := 1024;
        filter_file: string    := "filter_coefs.data"

		);
	port(
        clk	: in std_logic;
		rstn	: in std_logic;

		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
        din_user : in std_logic_vector(23 downto 0);

		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(23 downto 0);

        counter_in : out std_logic_vector(31 downto 0);
        counter_out: out std_logic_vector(31 downto 0);
        
        rc_axi_aclk    : IN STD_LOGIC;
        rc_axi_aresetn : IN STD_LOGIC;
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

signal din : std_logic_vector(31 downto 0);
signal din_en: std_logic;
signal din_last: std_logic;
signal din_user : std_logic_vector(23 downto 0);
    
signal dout: std_logic_vector(31 downto 0);
signal dout_en :std_logic;
signal dout_last: std_logic;
signal dout_user : std_logic_vector(23 downto 0);

signal d_fifo_full, d_fifo_almost_full, u_fifo_empty, u_fifo_al_empty, u_fifo_rden, dout_vld, dout_rdy : std_logic;

signal internal_fifo_status : std_logic_vector(7 downto 0);

begin


-- Instantiation of Axi Bus Interface S00_AXIS
axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,  --32
        C_S_AXIS_TUSER_WIDTH	=> C_M_AXIS_TUSER_WIDTH,  --24
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
        S_AXIS_TSTRB	=> s_axis_tstrb,
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);

    din_en <= u_fifo_rden and not u_fifo_empty;

    ram_multiply_inst: ram_multiply
        generic map(
            Nfft => Nfft,
            filter_file => filter_file
            )
        port map(
            clk    => s_axis_aclk,
            rstn    => s_axis_aresetn,

            din => din,
            din_en => din_en,
            din_last => din_last,
            din_user => din_user,
            
            dout => dout,
            dout_en => dout_en,
            dout_last => dout_last,
            dout_user => dout_user,

            counter_in => samples_in,
            counter_out=> samples_out,

            rc_axi_aclk     => rc_axi_aclk,
            rc_axi_aresetn  => rc_axi_aresetn,
            rc_axi_awaddr   => rc_axi_awaddr,
            rc_axi_awprot   => rc_axi_awprot,
            rc_axi_awvalid  => rc_axi_awvalid,
            rc_axi_awready  => rc_axi_awready,
            rc_axi_wdata    => rc_axi_wdata,
            rc_axi_wstrb    => rc_axi_wstrb,
            rc_axi_wvalid   => rc_axi_wvalid,
            rc_axi_wready   => rc_axi_wready,
            rc_axi_bresp    => rc_axi_bresp,
            rc_axi_bvalid   => rc_axi_bvalid,
            rc_axi_bready   => rc_axi_bready,
            rc_axi_araddr   => rc_axi_araddr,
            rc_axi_arprot   => rc_axi_arprot,
            rc_axi_arvalid  => rc_axi_arvalid,
            rc_axi_arready  => rc_axi_arready,
            rc_axi_rdata    => rc_axi_rdata,
            rc_axi_rresp    => rc_axi_rresp,
            rc_axi_rvalid   => rc_axi_rvalid,
            rc_axi_rready   => rc_axi_rready

            );


    --u_fifo_rden <= not d_fifo_full;
    u_fifo_rden <= not d_fifo_almost_full;
    
    -- Instantiation of Axi Bus Interface M00_AXIS
    axis_wrapper_maxis_inst : axis_wrapper_maxis
        generic map (
            C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
            C_M_AXIS_TUSER_WIDTH    => C_M_AXIS_TUSER_WIDTH,
            FIFO_MAX_DEPTH => 16,
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
            M_AXIS_TSTRB    => m_axis_tstrb,
            M_AXIS_TLAST    => m_axis_tlast,
            M_AXIS_TREADY    => m_axis_tready
        );

    internal_fifo_status(0) <= u_fifo_empty;
    internal_fifo_status(1) <= u_fifo_al_empty;
    internal_fifo_status(2) <= u_fifo_rden;
    internal_fifo_status(3) <= din_en;

    internal_fifo_status(4) <= d_fifo_full;
    internal_fifo_status(5) <= d_fifo_almost_full;
    internal_fifo_status(6) <= dout_en;
    internal_fifo_status(7) <= '0';
    
    fifo_status <= internal_fifo_status;

    


end arch_imp;
