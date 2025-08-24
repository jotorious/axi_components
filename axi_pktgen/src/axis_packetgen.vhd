library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;

entity axis_packetgen is
	generic (
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_AXIS_TUSER_WIDTH	: integer	:= 24;
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;

        C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 6;

        PKTLEN : integer := 2097152

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

        -- Ports of Axi Slave Bus Interface S00_AXI
		reg_intf_axi_aclk	: in std_logic;
		reg_intf_axi_aresetn	: in std_logic;
		reg_intf_axi_awaddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		reg_intf_axi_awprot	: in std_logic_vector(2 downto 0);
		reg_intf_axi_awvalid	: in std_logic;
		reg_intf_axi_awready	: out std_logic;
		reg_intf_axi_wdata	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		reg_intf_axi_wstrb	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		reg_intf_axi_wvalid	: in std_logic;
		reg_intf_axi_wready	: out std_logic;
		reg_intf_axi_bresp	: out std_logic_vector(1 downto 0);
		reg_intf_axi_bvalid	: out std_logic;
		reg_intf_axi_bready	: in std_logic;
		reg_intf_axi_araddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		reg_intf_axi_arprot	: in std_logic_vector(2 downto 0);
		reg_intf_axi_arvalid	: in std_logic;
		reg_intf_axi_arready	: out std_logic;
		reg_intf_axi_rdata	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		reg_intf_axi_rresp	: out std_logic_vector(1 downto 0);
		reg_intf_axi_rvalid	: out std_logic;
		reg_intf_axi_rready	: in std_logic

	);
end axis_packetgen;

architecture arch_imp of axis_packetgen is


component packetgen_ip is
	generic(
		PKTLEN : integer
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(23 downto 0);
        pktlen_reg : in std_logic_vector(31 downto 0);
        sample_count : out std_logic_vector(31 downto 0);
        opacket_count : out std_logic_vector(31 downto 0);
        ipacket_count : out std_logic_vector(31 downto 0);
        tot_sample_count : out std_logic_vector(31 downto 0)
		);
end component;
    
signal din : std_logic_vector(31 downto 0);
signal din_en: std_logic;
signal din_last: std_logic;
    
signal dout: std_logic_vector(31 downto 0);
signal dout_user: std_logic_vector(23 downto 0);
signal dout_en :std_logic;
signal dout_last: std_logic;

signal d_fifo_full, u_fifo_empty, u_fifo_al_empty, u_fifo_rden, dout_vld, dout_rdy, d_fifo_almost_full : std_logic;

--type reg_type is array (0 to 15) of std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
--signal reg : reg_type;

type reg_type is array (0 to 7) of std_logic_vector(C_S_AXI_DATA_WIDTH -1 downto 0);
signal status_reg, control_reg : reg_type;

signal resetn : std_logic;

begin
-- Instantiation of Axi Bus Interface reg_intf_AXI
axi_lite_inst : axi_lite
	generic map (
		C_S_AXI_DATA_WIDTH	=> C_S_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S_AXI_ADDR_WIDTH
	)
	port map (
		S_AXI_ACLK	=> reg_intf_axi_aclk,
		S_AXI_ARESETN	=> reg_intf_axi_aresetn,
		S_AXI_AWADDR	=> reg_intf_axi_awaddr,
		S_AXI_AWPROT	=> reg_intf_axi_awprot,
		S_AXI_AWVALID	=> reg_intf_axi_awvalid,
		S_AXI_AWREADY	=> reg_intf_axi_awready,
		S_AXI_WDATA	=> reg_intf_axi_wdata,
		S_AXI_WSTRB	=> reg_intf_axi_wstrb,
		S_AXI_WVALID	=> reg_intf_axi_wvalid,
		S_AXI_WREADY	=> reg_intf_axi_wready,
		S_AXI_BRESP	=> reg_intf_axi_bresp,
		S_AXI_BVALID	=> reg_intf_axi_bvalid,
		S_AXI_BREADY	=> reg_intf_axi_bready,
		S_AXI_ARADDR	=> reg_intf_axi_araddr,
		S_AXI_ARPROT	=> reg_intf_axi_arprot,
		S_AXI_ARVALID	=> reg_intf_axi_arvalid,
		S_AXI_ARREADY	=> reg_intf_axi_arready,
		S_AXI_RDATA	=> reg_intf_axi_rdata,
		S_AXI_RRESP	=> reg_intf_axi_rresp,
		S_AXI_RVALID	=> reg_intf_axi_rvalid,
		S_AXI_RREADY	=> reg_intf_axi_rready,
        -- Reg0 to 7 are from logic to CPU
        -- These area driven by logic here 
        reg0_rd => status_reg(0),  --offset 0x00
        reg1_rd => status_reg(1),  --offset 0x04
        reg2_rd => status_reg(2),
        reg3_rd => status_reg(3),
        reg4_rd => status_reg(4),  --offset 0x10
        reg5_rd => status_reg(5),
        reg6_rd => status_reg(6),
        reg7_rd => status_reg(7),  --offset 0x1C (4*reg_num-->Hex)
        -- Reg8 to 15 are from CPU to Logic
        -- these are sunk in this code
        reg8_wr  => control_reg(0), --offset 0x20
        reg9_wr  => control_reg(1),
        reg10_wr => control_reg(2),
        reg11_wr => control_reg(3), --offset 0x30
        reg12_wr => control_reg(4),
        reg13_wr => control_reg(5),
        reg14_wr => control_reg(6),
        reg15_wr => control_reg(7)  --offset 0x4C
        
	);


--Resets are active low
-- Both AH => OR, Both AL => AND
-- A AL and B AH => A AND NOT B
resetn <= s_axis_aresetn and not control_reg(0)(0);

status_reg(0) <= x"DEADC0DE";


axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,
        C_S_AXIS_TUSER_WIDTH	=> 16,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_EMPTY => 3
	)
	port map (
	    dout => din,
        dout_last => din_last,
        fifo_rden =>u_fifo_rden,
        fifo_empty => u_fifo_empty,
        fifo_almost_empty => u_fifo_al_empty,
	
		S_AXIS_ACLK	=> s_axis_aclk,
		S_AXIS_ARESETN	=> resetn,
		S_AXIS_TREADY	=> s_axis_tready,
		S_AXIS_TDATA	=> s_axis_tdata,
		S_AXIS_TUSER	=> (others=> '0'),
        S_AXIS_TSTRB	=> s_axis_tstrb,
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);

packetgen_inst: packetgen_ip
        generic map(
            PKTLEN => PKTLEN
            )
        port map(
            din => din,
            din_en => din_en,
            din_last => din_last,
            clk    => s_axis_aclk,
            rst    => resetn,
            dout => dout,
            dout_en => dout_en,
            dout_last => dout_last,
            dout_user => dout_user,
            -- Control from CPU
            pktlen_reg => control_reg(1),  --0x20
            -- Status to CPU
            sample_count => status_reg(1),  -- 0x04
            opacket_count => status_reg(2), -- 0x08
            ipacket_count => status_reg(3),
            tot_sample_count=> status_reg(4)
            );

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
            fifo_almost_full => d_fifo_almost_full,
                
            M_AXIS_ACLK    => s_axis_aclk,
            M_AXIS_ARESETN    => resetn,
            M_AXIS_TVALID    => m_axis_tvalid,
            M_AXIS_TDATA    => m_axis_tdata,
            M_AXIS_TUSER    => m_axis_tuser,
            M_AXIS_TSTRB    => m_axis_tstrb,
            M_AXIS_TLAST    => m_axis_tlast,
            M_AXIS_TREADY    => m_axis_tready
        );

    --u_fifo_rden <= not d_fifo_full;
    u_fifo_rden <= not d_fifo_almost_full;

    din_en <= u_fifo_rden and not u_fifo_empty;


end arch_imp;
