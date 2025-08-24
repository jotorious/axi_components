library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;

use work.axis_packet_mux_pkg.all;

package overlap_save_pkg is
    	-- component declaration
component overlap_inputs_axis
	generic (
        P : integer range 8 to 1024:= 1024;   -- P is overlap length (also filter length)
        N : integer range 16 to 4096:= 4096;  -- N is FFT Length-- User parameters ends
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_AXIS_START_COUNT	: integer	:= 32;
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_aclk	: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
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
		s_axis_tvalid	: in std_logic
	);
end component;

component axis_overlap_inputs
	generic (
        RAMDEPTH : integer := 1024;
        C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
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
end component;

COMPONENT axis_packet_buffer
  PORT (
    s_axis_aresetn : IN STD_LOGIC;
    s_axis_aclk : IN STD_LOGIC;
    s_axis_tvalid : IN STD_LOGIC;
    s_axis_tready : OUT STD_LOGIC;
    s_axis_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_tlast : IN STD_LOGIC;
    s_axis_tuser : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axis_tvalid : OUT STD_LOGIC;
    m_axis_tready : IN STD_LOGIC;
    m_axis_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_tlast : OUT STD_LOGIC;
    m_axis_tuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    axis_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    axis_wr_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    axis_rd_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

component axis_fft_rearrange
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
end component;


component axis_rom_multiply
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
        samples_out: out std_logic_vector(31 downto 0)
	);
end component;

component axis_ram_multiply
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
end component;


component axis_stack_add
	generic (
	   RAMDEPTH : integer := 32;
       --PKTLENOUT : integer := 32;
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
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
		
		pktlen_in : in std_logic_vector(31 downto 0);
        pktlen_out : in std_logic_vector(31 downto 0);
        pktlen_ratio : in std_logic_vector(31 downto 0);

        samples_in : out std_logic_vector(31 downto 0);
        samples_out: out std_logic_vector(31 downto 0);

        fifo_status : out std_logic_vector(7 downto 0)
	);
end component;



----------------
-- FFT DData In and Out are: 31-16 is IM, 15-0 is RE

COMPONENT xfft_0
  PORT (
    aclk : IN STD_LOGIC;
  aclken : IN STD_LOGIC;
  aresetn : IN STD_LOGIC;
  s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
  s_axis_config_tvalid : IN STD_LOGIC;
  s_axis_config_tready : OUT STD_LOGIC;
  s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
  s_axis_data_tvalid : IN STD_LOGIC;
  s_axis_data_tready : OUT STD_LOGIC;
  s_axis_data_tlast : IN STD_LOGIC;
  m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
  m_axis_data_tuser : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
  m_axis_data_tvalid : OUT STD_LOGIC;
  m_axis_data_tready : IN STD_LOGIC;
  m_axis_data_tlast : OUT STD_LOGIC;
  m_axis_status_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
  m_axis_status_tvalid : OUT STD_LOGIC;
  m_axis_status_tready : IN STD_LOGIC;
  event_frame_started : OUT STD_LOGIC;
  event_tlast_unexpected : OUT STD_LOGIC;
  event_tlast_missing : OUT STD_LOGIC;
  event_status_channel_halt : OUT STD_LOGIC;
  event_data_in_channel_halt : OUT STD_LOGIC;
  event_data_out_channel_halt : OUT STD_LOGIC
  );
END COMPONENT;

--component cmpy_0
--  Port ( 
--    aclk : in STD_LOGIC;
--    aresetn : in STD_LOGIC;
--    s_axis_a_tvalid : in STD_LOGIC;
--    s_axis_a_tuser : in STD_LOGIC_VECTOR ( 23 downto 0 );
--    s_axis_a_tlast : in STD_LOGIC;
--    s_axis_a_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
--    s_axis_b_tvalid : in STD_LOGIC;
--    s_axis_b_tlast : in STD_LOGIC;
--    s_axis_b_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
--    m_axis_dout_tvalid : out STD_LOGIC;
--    m_axis_dout_tuser : out STD_LOGIC_VECTOR ( 23 downto 0 );
--    m_axis_dout_tlast : out STD_LOGIC;
--    m_axis_dout_tdata : out STD_LOGIC_VECTOR ( 63 downto 0 )
--  ); 
--END COMPONENT;

--component inferred_rom
--    GENERIC (
--        depth : integer;
--        data_in_file: string 
--    );
--    PORT (
--        clka : IN STD_LOGIC;
--        ena : IN STD_LOGIC;
--        addra : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
--    );
--end component;

 COMPONENT axis_data_fifo_32_x16
   PORT (
     s_axis_aresetn : IN STD_LOGIC;
     s_axis_aclk : IN STD_LOGIC;
     s_axis_tvalid : IN STD_LOGIC;
     s_axis_tready : OUT STD_LOGIC;
     s_axis_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
     s_axis_tuser : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
     s_axis_tlast : IN STD_LOGIC;
     m_axis_tvalid : OUT STD_LOGIC;
     m_axis_tready : IN STD_LOGIC;
     m_axis_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     M_axis_tuser : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
     m_axis_tlast : OUT STD_LOGIC;
     axis_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     axis_wr_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     axis_rd_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
   );
 END COMPONENT;
 
component axis_discard_samples
    generic (
        --Nfft : integer := 32;
        --P    : integer := 8;
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
        s_axis_tuser	: in std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        N : in std_logic_vector(15 downto 0);
        P : in std_logic_vector(15 downto 0);

        fifo_status : out std_logic_vector(7 downto 0)
	);
end component;

component axis_fanout
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 24;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 24;
        NUM_MASTERS               : integer   := 4
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser    : in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
        s_axis_tstrb	: in std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out type_tvalid(0 to NUM_MASTERS-1);
		m_axis_tdata	: out type_tdata(0 to NUM_MASTERS-1);
		m_axis_tstrb	: out type_tstrb(0 to NUM_MASTERS-1);
        m_axis_tuser	: out type_tuser24(0 to NUM_MASTERS-1);
		m_axis_tlast	: out type_tlast(0 to NUM_MASTERS-1);
		m_axis_tready	: in type_tready(0 to NUM_MASTERS-1)

	);
end component;


component axis_packet_mux is
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer;
        C_M_AXIS_TUSER_WIDTH	: integer;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer;
        NUM_SLAVES               : integer
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

		s_axis_tready	: out type_tready(0 to NUM_SLAVES-1);
		s_axis_tdata	: in type_tdata(0 to NUM_SLAVES-1);
        s_axis_tuser    : in type_tuser(0 to NUM_SLAVES-1);
        s_axis_tstrb	: in type_tstrb(0 to NUM_SLAVES-1);
		s_axis_tlast	: in type_tlast(0 to NUM_SLAVES-1);
		s_axis_tvalid	: in type_tvalid(0 to NUM_SLAVES-1);

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic

	);
end component;

component axis_packet_demux
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 16;
        NUM_MASTERS               : integer   := 4
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser    : in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
        s_axis_tstrb	: in std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out type_tvalid(0 to NUM_MASTERS-1);
		m_axis_tdata	: out type_tdata(0 to NUM_MASTERS-1);
		m_axis_tstrb	: out type_tstrb(0 to NUM_MASTERS-1);
        m_axis_tuser	: out type_tuser(0 to NUM_MASTERS-1);
		m_axis_tlast	: out type_tlast(0 to NUM_MASTERS-1);
		m_axis_tready	: in type_tready(0 to NUM_MASTERS-1)

	);
end component;

component axis_multi_ram_multiply
	generic (
	    Nfft : integer := 1024;
        filter_file: string    := "filter_coefs.data";
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer   := 24;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 24;
        NUM_CHANS            : integer   := 4
	);
	port (
	    s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
        
        -- Ports of Axi Slave Bus Interface S00_AXIS
        s_axis_tready	: out type_tready(0 to NUM_CHANS-1);
		s_axis_tdata	: in type_tdata(0 to NUM_CHANS-1);
        s_axis_tuser    : in type_tuser24(0 to NUM_CHANS-1);
        s_axis_tstrb	: in type_tstrb(0 to NUM_CHANS-1);
		s_axis_tlast	: in type_tlast(0 to NUM_CHANS-1);
		s_axis_tvalid	: in type_tvalid(0 to NUM_CHANS-1);

        -- Ports of Axi Master Bus Interface M00_AXIS
        m_axis_tready	: in type_tready(0 to NUM_CHANS-1);
		m_axis_tdata	: out type_tdata(0 to NUM_CHANS-1);
        m_axis_tuser    : out type_tuser24(0 to NUM_CHANS-1);
        m_axis_tstrb	: out type_tstrb(0 to NUM_CHANS-1);
		m_axis_tlast	: out type_tlast(0 to NUM_CHANS-1);
		m_axis_tvalid	: out type_tvalid(0 to NUM_CHANS-1);

        samples_in : out std_logic_vector(31 downto 0);
        samples_out: out std_logic_vector(31 downto 0);

        rc_axi_aclk    : IN STD_LOGIC;
        rc_axi_aresetn : IN STD_LOGIC;
        rc_axi_awaddr  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
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
        rc_axi_araddr  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        rc_axi_arprot  : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        rc_axi_arvalid : IN STD_LOGIC;
        rc_axi_arready : OUT STD_LOGIC;
        rc_axi_rdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        rc_axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        rc_axi_rvalid  : OUT STD_LOGIC;
        rc_axi_rready  : IN STD_LOGIC;

        fifo_status : out std_logic_vector(7 downto 0)
	);
end component;









COMPONENT ila_0
PORT (
	clk : IN STD_LOGIC;
	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END COMPONENT  ;







type axi_stream32 is record
    tdata : std_logic_vector(31 downto 0);
    tuser : std_logic_vector(23 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream32;

constant axis32_init : axi_stream32 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');

type axi_stream24 is record
    tdata : std_logic_vector(23 downto 0);
    tuser : std_logic_vector(15 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream24;

constant axis24_init : axi_stream24 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');
                                              
type axi_stream16 is record
  tdata : std_logic_vector(15 downto 0);
  tuser : std_logic_vector(15 downto 0);
  tvalid : std_logic;
  tready : std_logic;
  tlast  : std_logic;
end record axi_stream16;
  
constant axis16_init : axi_stream16 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');
                                        
type axi_stream8 is record
  tdata : std_logic_vector(7 downto 0);
  tuser : std_logic_vector(7 downto 0);
  tvalid : std_logic;
  tready : std_logic;
  tlast  : std_logic;
end record axi_stream8;
  
constant axis8_init : axi_stream8 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');



end overlap_save_pkg;
