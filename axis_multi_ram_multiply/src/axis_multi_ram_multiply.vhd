library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;
use work.axis_packet_mux_pkg.all;

entity axis_multi_ram_multiply is
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
end axis_multi_ram_multiply;

architecture arch_imp of axis_multi_ram_multiply is

--Ceiling Log2
function clog2 (bit_depth : integer) return integer is                  
	 	variable depth  : integer := bit_depth;                               
	 	variable count  : integer := 0;                                       
	 begin                                                                   
	 	 for clogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
	      if (bit_depth <= 2) then                                           
	        count := 1;                                                      
	      else                                                               
	        if(depth <= 1) then                                              
	 	       count := count;                                                
	 	    else                                                             
	 	      depth := depth / 2;                                            
	          count := count + 1;                                            
	 	    end if;                                                          
	 	  end if;                                                            
	   end loop;                                                             
	   return(count);        	                                              
	 end;




component ram_multiply_ext_bram_ctrl
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

        bram_rst : in std_logic;
        bram_clk : in STD_LOGIC;
        bram_en : in STD_LOGIC;
        bram_we: in STD_LOGIC_VECTOR(3 DOWNTO 0);
        bram_addr_long : in STD_LOGIC_VECTOR(31 DOWNTO 0);
        bram_wrdata : in STD_LOGIC_VECTOR(31 DOWNTO 0);
        bram_rddata : out STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
end component;

COMPONENT axi_bram_ctrl_16k
  PORT (
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    s_axi_awaddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_araddr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC;
    bram_rst_a : OUT STD_LOGIC;
    bram_clk_a : OUT STD_LOGIC;
    bram_en_a : OUT STD_LOGIC;
    bram_we_a : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    bram_addr_a : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    bram_wrdata_a : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    bram_rddata_a : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;


--signal din : std_logic_vector(31 downto 0);
--signal din_en: std_logic;
--signal din_last: std_logic;
--signal din_user : std_logic_vector(23 downto 0);
    
--ssignal dout: std_logic_vector(31 downto 0);
--signal dout_en :std_logic;
--signal dout_last: std_logic;
--signal dout_user : std_logic_vector(23 downto 0);

--signal d_fifo_full, d_fifo_almost_full, u_fifo_empty, u_fifo_al_empty, u_fifo_rden, dout_vld, dout_rdy : std_logic;

signal internal_fifo_status : std_logic_vector(7 downto 0);

signal din, dout, i_samples_in, i_samples_out : type_tdata(0 to NUM_CHANS-1);
signal din_en, dout_en: type_tvalid(0 to NUM_CHANS-1);
signal din_last, dout_last: type_tlast(0 to NUM_CHANS-1);
signal din_user, dout_user: type_tuser24(0 to NUM_CHANS-1);
signal u_fifo_empty, u_fifo_al_empty, u_fifo_rden : type_tvalid(0 to NUM_CHANS-1);
signal d_fifo_full, d_fifo_almost_full, d_not_almost_full : type_tvalid(0 to NUM_CHANS-1);



--RAM ctrl interface signals
signal bram_rst : std_logic;
signal bram_clk :STD_LOGIC;
signal bram_en : STD_LOGIC;
signal bram_we: STD_LOGIC_VECTOR(NUM_CHANS-1 downto 0);
signal bram_addr : STD_LOGIC_VECTOR(15 DOWNTO 0);

signal bram_addr_long : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal bram_wrdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal bram_rddata : type_tdata(0 to NUM_CHANS-1); -- array 0 to 3 of slv(31 dt 0)
signal bram_rddata_switch : STD_LOGIC_VECTOR(31 DOWNTO 0);

signal bram_ce : std_logic_vector(NUM_CHANS-1 downto 0);
signal bram_cen : std_logic_vector(NUM_CHANS-1 downto 0);

constant MSB_ADDR : integer := 12;
constant DECODE_BITS : integer := clog2(NUM_CHANS);
constant UDB : integer := MSB_ADDR + DECODE_BITS;
constant LDB : integer := MSB_ADDR + DECODE_BITS - 1;

--type addr_decode_range is range UDB downto LDB; -- range is always DECODE_BITS wide.



begin

--bram_addr is 13 bit Byte address
-- so the 11 bit word address is bram_addr(bram_addr'left downto bram_addr'right+2)
bram_addr_long <= x"00000" & '0' & bram_addr(12 downto 2);

--bram_ce(0) <= not bram_addr(14) and not bram_addr(13);
--bram_ce(1) <= not bram_addr(14) and     bram_addr(13);
--bram_ce(2) <=     bram_addr(14) and not bram_addr(13);
--bram_ce(3) <=     bram_addr(14) and     bram_addr(13);

samples_in <= i_samples_in(0);
samples_out <= i_samples_out(0);



axi_lite_bram_ctrl_inst : axi_bram_ctrl_16k
  PORT MAP (
    s_axi_aclk => rc_axi_aclk,
    s_axi_aresetn => rc_axi_aresetn,
    s_axi_awaddr => rc_axi_awaddr,
    s_axi_awprot => rc_axi_awprot,
    s_axi_awvalid => rc_axi_awvalid,
    s_axi_awready => rc_axi_awready,
    s_axi_wdata => rc_axi_wdata,
    s_axi_wstrb => rc_axi_wstrb,
    s_axi_wvalid => rc_axi_wvalid,
    s_axi_wready => rc_axi_wready,
    s_axi_bresp => rc_axi_bresp,
    s_axi_bvalid => rc_axi_bvalid,
    s_axi_bready => rc_axi_bready,
    s_axi_araddr => rc_axi_araddr,
    s_axi_arprot => rc_axi_arprot,
    s_axi_arvalid => rc_axi_arvalid,
    s_axi_arready => rc_axi_arready,
    s_axi_rdata => rc_axi_rdata,
    s_axi_rresp => rc_axi_rresp,
    s_axi_rvalid => rc_axi_rvalid,
    s_axi_rready => rc_axi_rready,

    bram_rst_a => bram_rst,
    bram_clk_a => bram_clk,
    bram_en_a => bram_en,
    bram_we_a => bram_we,
    bram_addr_a => bram_addr,
    bram_wrdata_a => bram_wrdata,
    bram_rddata_a => bram_rddata_switch
  );

--bram_rddata_switch <= bram_rddata(0) when unsigned(bram_addr(addr_decode_range)) = 0 else
--                      bram_rddata(1) when unsigned(bram_addr(addr_decode_range)) = 1 else
--                      bram_rddata(2) when unsigned(bram_addr(addr_decode_range)) = 2 else
--                      bram_rddata(3) when unsigned(bram_addr(addr_decode_range)) = 3 else
--                      (others=>'0');

--bram_rddata_switch <= bram_rddata(unsigned(bram_addr(UDB downto LDB)));

main_gen: for i in 0 to NUM_CHANS-1 generate

    bram_ce(i) <= '1' when unsigned(bram_addr(UDB downto LDB)) = i else '0';

    bram_cen(i) <= bram_en and bram_ce(i);

    -- Instantiation of Axi Bus Interface S00_AXIS
    axis_wrapper_saxis_inst : axis_wrapper_saxis
	    generic map (
		    C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,  --32
            C_S_AXIS_TUSER_WIDTH	=> C_S_AXIS_TUSER_WIDTH,  --24
            FIFO_MAX_DEPTH => 8,
            FIFO_PROG_EMPTY => 3
	    )
	    port map (
	        dout => din(i),
            dout_last => din_last(i),
            dout_user => din_user(i),
            fifo_rden =>u_fifo_rden(i),
            fifo_empty => u_fifo_empty(i),
            fifo_almost_empty => u_fifo_al_empty(i),
	
		    S_AXIS_ACLK	=> s_axis_aclk,
		    S_AXIS_ARESETN	=> s_axis_aresetn,
		    S_AXIS_TREADY	=> s_axis_tready(i),
		    S_AXIS_TDATA	=> s_axis_tdata(i),
		    S_AXIS_TUSER	=> s_axis_tuser(i),
            S_AXIS_TSTRB	=> s_axis_tstrb(i),
		    S_AXIS_TLAST	=> s_axis_tlast(i),
		    S_AXIS_TVALID	=> s_axis_tvalid(i)
	    );

    din_en(i) <= u_fifo_rden(i) and not u_fifo_empty(i);

    ram_multiply_inst: ram_multiply_ext_bram_ctrl
        generic map(
            Nfft => Nfft,
            filter_file => filter_file
            )
        port map(
            clk    => s_axis_aclk,
            rstn    => s_axis_aresetn,

            din => din(i),
            din_en => din_en(i),
            din_last => din_last(i),
            din_user => din_user(i),
            
            dout => dout(i),
            dout_en => dout_en(i),
            dout_last => dout_last(i),
            dout_user => dout_user(i),

            counter_in => i_samples_in(i),
            counter_out=> i_samples_out(i),

            bram_rst => bram_rst,
            bram_clk => bram_clk,
            bram_en => bram_cen(i),
            bram_we => bram_we,
            bram_addr_long => bram_addr_long,
            bram_wrdata => bram_wrdata,
            bram_rddata => bram_rddata(i)
            );



    --u_fifo_rden <= not d_fifo_full;
    u_fifo_rden(i) <= not d_fifo_almost_full(i);
    
    -- Instantiation of Axi Bus Interface M00_AXIS
    axis_wrapper_maxis_inst : axis_wrapper_maxis
        generic map (
            C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
            C_M_AXIS_TUSER_WIDTH    => C_M_AXIS_TUSER_WIDTH,
            FIFO_MAX_DEPTH => 16,
            FIFO_PROG_FULL => 4
        )
        port map (
            din => dout(i),
            din_en =>dout_en(i),
            din_user => dout_user(i),
            din_last => dout_last(i),
            fifo_full => d_fifo_full(i),
            fifo_almost_Full => d_fifo_almost_full(i),
                
            M_AXIS_ACLK    => s_axis_aclk,
            M_AXIS_ARESETN    => s_axis_aresetn,
            M_AXIS_TVALID    => m_axis_tvalid(i),
            M_AXIS_TDATA    => m_axis_tdata(i),
            M_AXIS_TUSER    => m_axis_tuser(i),
            M_AXIS_TSTRB    => m_axis_tstrb(i),
            M_AXIS_TLAST    => m_axis_tlast(i),
            M_AXIS_TREADY    => m_axis_tready(i)
        );

end generate;

    internal_fifo_status(0) <= u_fifo_empty(0);
    internal_fifo_status(1) <= u_fifo_al_empty(0);
    internal_fifo_status(2) <= u_fifo_rden(0);
    internal_fifo_status(3) <= din_en(0);

    internal_fifo_status(4) <= d_fifo_full(0);
    internal_fifo_status(5) <= d_fifo_almost_full(0);
    internal_fifo_status(6) <= dout_en(0);
    internal_fifo_status(7) <= '0';
    
    fifo_status <= internal_fifo_status;

    


end arch_imp;
