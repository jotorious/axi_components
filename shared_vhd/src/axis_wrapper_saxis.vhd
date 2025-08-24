library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_wrapper_saxis is
	generic (
		-- AXI4Stream sink: Data Width
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 16;
        -- Max Fifo Depth
        FIFO_MAX_DEPTH : integer range 3 to 512 := 8;
        -- Programmable EMPTY Threshold
        FIFO_PROG_EMPTY : integer range 2 to 32 := 3
	);
	port (
		-- Users to add ports here
		dout : out std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        dout_user : out std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
        dout_last : out std_logic;
		fifo_rden : in std_logic;
		fifo_empty : out std_logic;
		fifo_almost_empty : out std_logic;

		S_AXIS_ACLK	: in std_logic;
		S_AXIS_ARESETN	: in std_logic;

		S_AXIS_TVALID	: in std_logic;
        S_AXIS_TREADY	: out std_logic;
		S_AXIS_TDATA	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        S_AXIS_TUSER	: in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
		S_AXIS_TSTRB	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		S_AXIS_TLAST	: in std_logic
	);
end axis_wrapper_saxis;

architecture arch_imp of axis_wrapper_saxis is
  
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

  type axis_bus is record
      tdata : std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
      tuser : std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
      tlast  : std_logic;
  end record axis_bus;

  constant axis_bus_init : axis_bus := (    tdata => (others=> '0'),
                                            tuser => (others=> '0'),
                                            tlast => '0');

  type RAM_AXISD is array ((FIFO_MAX_DEPTH-1) downto 0) of axis_bus;
  signal fifo : RAM_AXISD := (others => axis_bus_init);

  signal din_axis_bus : axis_bus;

  constant fifo_addr_width : integer := clog2(FIFO_MAX_DEPTH);

  signal fifo_index_i    : signed (fifo_addr_width downto 0) := to_signed(-1, fifo_addr_width+1);
  signal fifo_empty_b      : boolean;
  signal fifo_full_b     : boolean;
  signal fifo_in_enable  : boolean;
  signal fifo_out_enable : boolean;
  signal debug_raddr : integer;

begin

  din_axis_bus.tdata <= S_AXIS_TDATA;
  din_axis_bus.tlast <= S_AXIS_TLAST;
  din_axis_bus.tuser <= S_AXIS_TUSER;

  fifo_empty_b      <= (fifo_index_i = -1);
  fifo_full_b       <= (fifo_index_i = FIFO_MAX_DEPTH-1);
  
  fifo_empty <= '1' when (fifo_empty_b) else '0';
  fifo_almost_empty   <= '1' when (to_integer(fifo_index_i) <= FIFO_PROG_EMPTY) else '0';

  S_AXIS_TREADY   <= '1' when (not  fifo_full_b) else '0';
  
  fifo_in_enable  <= (S_AXIS_TVALID  = '1') and (not fifo_full_b );
  fifo_out_enable <= (fifo_rden = '1') and (not fifo_empty_b);




  dout   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tdata; 
  dout_user   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tuser; 
  dout_last   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tlast;

  debug_raddr <= to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)));

  -- Implement a Shift Register
  process (S_AXIS_ACLK)
  begin
    if rising_edge(S_AXIS_ACLK) then
      if fifo_in_enable then
        fifo <= fifo(FIFO_MAX_DEPTH-2 downto 0) & din_axis_bus;
      end if;
    end if;  
  end process;

 -- Track and choose output point
 -- in_enable and not out_enable eplicit incr index
 -- in_enable and out_enable implicit don't change index
 -- not in_enable and out_enable explicit decr index
 -- not in_enable and not out_enable implicit don't change index

 process (S_AXIS_ACLK)
  begin
    if rising_edge(S_AXIS_ACLK) then
      if fifo_in_enable then
        if not fifo_out_enable then
            fifo_index_i <= fifo_index_i + 1;
        end if;
      elsif fifo_out_enable then
        fifo_index_i <= fifo_index_i - 1;
      end if;
    end if;  
  end process;

end arch_imp;
