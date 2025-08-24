library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package axis_tb_package is

    --AXI-Stream Source generator
    component m_axis_source
        generic (
            PKTLEN : integer:= 32;
            PKTS_TO_SOURCE : integer := 32;
            infname : string := "infile.hexascii";
            CPS : integer := 1
        );
        port (
		    M_AXIS_ACLK	: in std_logic;
		    M_AXIS_ARESETN	: in std_logic;

		    M_AXIS_TVALID	: out std_logic;
		    M_AXIS_TREADY	: in std_logic;
		    M_AXIS_TDATA	: out std_logic_vector(31 downto 0);
		    M_AXIS_TUSER	: out std_logic_vector(15 downto 0);
		    M_AXIS_TSTRB	: out std_logic_vector(3 downto 0);
		    M_AXIS_TLAST	: out std_logic;
            samples_read    : out integer
        );
    end component;

    --AXI-Stream Sink
    component s_axis_sink
        generic (
            PKTLEN : integer;
            outfname : string;
            CPS : integer
        );
        port (
		    S_AXIS_ACLK	: in std_logic;
		    S_AXIS_ARESETN	: in std_logic;
 
		    S_AXIS_TVALID	: in std_logic;
		    S_AXIS_TREADY	: out std_logic;
            S_AXIS_TDATA	: in std_logic_vector(31 downto 0);
		    S_AXIS_TUSER	: in std_logic_vector(15 downto 0);
		    S_AXIS_TSTRB	: in std_logic_vector(3 downto 0);
		    S_AXIS_TLAST	: in std_logic;
            samples_written : out integer
        );
    end component;

    component s_axis_verifysink
    generic (
        PKTLEN : integer;
        PKTS_TO_SINK : integer;
        outfname : string := "outfile.dat";
        verfname : string := "infile.dat";
        CPS : integer
    );
    port (
-- Global ports
		S_AXIS_ACLK	: in std_logic;
		S_AXIS_ARESETN	: in std_logic;
 
		S_AXIS_TVALID	: in std_logic;
		S_AXIS_TDATA	: in std_logic_vector(31 downto 0);
		S_AXIS_TUSER	: in std_logic_vector(15 downto 0);
		S_AXIS_TSTRB	: in std_logic_vector(3 downto 0);

		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TREADY	: out std_logic;

        samples_written : out integer;
        done            : out boolean
    );
end component;




    --Axi-lite Master
    component m_axi_lite
	generic (
		C_M_AXI_ADDR_WIDTH	: integer	:= 32;
		C_M_AXI_DATA_WIDTH	: integer	:= 32

	);
	port (

		M_AXI_ACLK	: in std_logic;
		M_AXI_ARESETN	: in std_logic;
		
        M_AXI_AWADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_AWPROT	: out std_logic_vector(2 downto 0);
		M_AXI_AWVALID	: out std_logic;
		M_AXI_AWREADY	: in std_logic;

		M_AXI_WDATA	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_WSTRB	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		M_AXI_WVALID	: out std_logic;
		M_AXI_WREADY	: in std_logic;

		M_AXI_BRESP	: in std_logic_vector(1 downto 0);
		M_AXI_BVALID	: in std_logic;
		M_AXI_BREADY	: out std_logic;

		M_AXI_ARADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_ARPROT	: out std_logic_vector(2 downto 0);
		M_AXI_ARVALID	: out std_logic;
		M_AXI_ARREADY	: in std_logic;

		M_AXI_RDATA	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_RRESP	: in std_logic_vector(1 downto 0);
		M_AXI_RVALID	: in std_logic;
		M_AXI_RREADY	: out std_logic;
        done    : out std_logic
	);
end component;

--Axi-lite Master
    component m_axi_lite_ram
	generic (
		C_M_AXI_ADDR_WIDTH	: integer	:= 32;
		C_M_AXI_DATA_WIDTH	: integer	:= 32

	);
	port (

		M_AXI_ACLK	: in std_logic;
		M_AXI_ARESETN	: in std_logic;
		
        M_AXI_AWADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_AWPROT	: out std_logic_vector(2 downto 0);
		M_AXI_AWVALID	: out std_logic;
		M_AXI_AWREADY	: in std_logic;

		M_AXI_WDATA	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_WSTRB	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		M_AXI_WVALID	: out std_logic;
		M_AXI_WREADY	: in std_logic;

		M_AXI_BRESP	: in std_logic_vector(1 downto 0);
		M_AXI_BVALID	: in std_logic;
		M_AXI_BREADY	: out std_logic;

		M_AXI_ARADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_ARPROT	: out std_logic_vector(2 downto 0);
		M_AXI_ARVALID	: out std_logic;
		M_AXI_ARREADY	: in std_logic;

		M_AXI_RDATA	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_RRESP	: in std_logic_vector(1 downto 0);
		M_AXI_RVALID	: in std_logic;
		M_AXI_RREADY	: out std_logic;
        done    : out std_logic
	);
end component;



    
    type axi_stream32 is record
        tdata : std_logic_vector(31 downto 0);
        tuser : std_logic_vector(15 downto 0);
        tvalid : std_logic;
        tready : std_logic;
        tlast  : std_logic;
    end record axi_stream32;
    
    --signal testin : axi_stream32;
    --signal testout : axi_stream32;
    
    type tb_axi32 is record
        mybus : axi_stream32;
        q : std_logic_vector(15 downto 0);
        i : std_logic_vector(15 downto 0);
        hsv: std_logic;
    end record tb_axi32;
    
    
    type axi_lite is record
        AWADDR    :  std_logic_vector(7 downto 0);
        AWPROT    :  std_logic_vector(2 downto 0);
        AWVALID    :  std_logic;
        AWREADY    : std_logic;
        WDATA    : std_logic_vector(31 downto 0);
        WSTRB    : std_logic_vector(3 downto 0);
        WVALID    : std_logic;
        WREADY    : std_logic;
        BRESP    : std_logic_vector(1 downto 0);
        BVALID    : std_logic;
        BREADY    : std_logic;
        ARADDR    : std_logic_vector(7 downto 0);
        ARPROT    : std_logic_vector(2 downto 0);
        ARVALID    : std_logic;
        ARREADY    : std_logic;
        RDATA    : std_logic_vector(31 downto 0);
        RRESP    : std_logic_vector(1 downto 0);
        RVALID    : std_logic;
        RREADY    : std_logic;
    end record axi_lite;

type axi_lite_ram is record
        AWADDR    :  std_logic_vector(12 downto 0);
        AWPROT    :  std_logic_vector(2 downto 0);
        AWVALID    :  std_logic;
        AWREADY    : std_logic;
        WDATA    : std_logic_vector(31 downto 0);
        WSTRB    : std_logic_vector(3 downto 0);
        WVALID    : std_logic;
        WREADY    : std_logic;
        BRESP    : std_logic_vector(1 downto 0);
        BVALID    : std_logic;
        BREADY    : std_logic;
        ARADDR    : std_logic_vector(12 downto 0);
        ARPROT    : std_logic_vector(2 downto 0);
        ARVALID    : std_logic;
        ARREADY    : std_logic;
        RDATA    : std_logic_vector(31 downto 0);
        RRESP    : std_logic_vector(1 downto 0);
        RVALID    : std_logic;
        RREADY    : std_logic;
    end record axi_lite_ram;

end axis_tb_package;
