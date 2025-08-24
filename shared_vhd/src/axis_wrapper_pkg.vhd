library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axis_wrapper_pkg is
    	-- component declaration
    component axis_wrapper_saxis is
	    generic (
		    C_S_AXIS_TDATA_WIDTH	: integer;
            C_S_AXIS_TUSER_WIDTH	: integer;
            -- Max Fifo Depth
            FIFO_MAX_DEPTH : integer;
            -- Programmable EMPTY Threshold
            FIFO_PROG_EMPTY : integer
	    );
	    port (
		    -- Users to add ports here
		    dout : out std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
            dout_user : out std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
		    dout_last : out std_logic;
		    fifo_rden : in std_logic;
		    fifo_empty : out std_logic;
		    fifo_almost_empty : out std_logic;

		    -- AXI4Stream sink: Clock
		    S_AXIS_ACLK	: in std_logic;
		    -- AXI4Stream sink: Reset
		    S_AXIS_ARESETN	: in std_logic;
		    -- Ready to accept data in
		    S_AXIS_TREADY	: out std_logic;
		    -- Data in
		    S_AXIS_TDATA	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
            S_AXIS_TUSER	: in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
		    -- Byte qualifier
		    S_AXIS_TSTRB	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		    -- Indicates boundary of last packet
		    S_AXIS_TLAST	: in std_logic;
		    -- Data is in valid
		    S_AXIS_TVALID	: in std_logic
	    );
    end component;

    component axis_wrapper_maxis is
	    generic (
            -- Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		    C_M_AXIS_TDATA_WIDTH	: integer;
            C_M_AXIS_TUSER_WIDTH	: integer;
            -- Max Fifo Depth
            FIFO_MAX_DEPTH : integer;
            FIFO_PROG_FULL : integer
	    );
	    port (
            din : in std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
            din_user : in std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
            din_en : in std_logic;
            din_last : in std_logic;
            fifo_full : out std_logic;
		    fifo_almost_full : out std_logic;
            -- Global ports
		    M_AXIS_ACLK	: in std_logic;
		    M_AXIS_ARESETN	: in std_logic;
            -- MAXIS
		    M_AXIS_TVALID	: out std_logic;
            M_AXIS_TREADY	: in std_logic;
		    M_AXIS_TDATA	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		    M_AXIS_TUSER	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		    M_AXIS_TSTRB	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		    M_AXIS_TLAST	: out std_logic
	    );
    end component;

    component axi_lite is
		generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 6
		);
		port (
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic;

        reg0_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg1_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg2_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg3_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg4_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg5_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg6_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg7_rd : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg8_wr  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg9_wr  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg10_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg11_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg12_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg13_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg14_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        reg15_wr : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0)
		);
	end component;

    -- Internal to axi_lite64, the register_array type might be defined as is defined as :
    -- type register_array is array (0 to 31) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    -- It might be worth trying to make everything constrained w/generics at synthesis time
 
    -- ie pass generics to the package to un-hardcode the following 31's
    type register_array is array (0 to 31) of std_logic_vector(31 downto 0);

    component axi_lite64 is
	generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 8
	);
	port (
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;

		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic;

        registers_out_to_logic  : out register_array;
        registers_in_to_bus     : in register_array
	);
    end component;






end axis_wrapper_pkg;
