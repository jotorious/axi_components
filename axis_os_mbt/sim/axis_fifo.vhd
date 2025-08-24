library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_fifo is
  generic (
    DWIDTH : integer :=  32;  -- FIFO data width
    FIFO_MAX_DEPTH : integer := 256;
    FIFO_PROG_FULL : integer := 252;
    FIFO_PROG_EMPTY: integer := 4
  );
  port (
    clk            : in std_logic;
    
    -- FIFO data input
    S_AXIS_TDATA   : in  std_logic_vector(DWIDTH-1 downto 0);
    S_AXIS_TVALID  : in  std_logic;
    S_AXIS_TREADY  : out std_logic := '0';

    -- FIFO data output
    M_AXIS_TDATA  : out std_logic_vector(DWIDTH-1 downto 0) := (others => '0');
    M_AXIS_TVALID : out std_logic := '0';
    M_AXIS_TREADY : in  std_logic
);
end axis_fifo;

architecture arch of axis_fifo is

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

  constant fifo_addr_width : integer := clog2(FIFO_MAX_DEPTH);

  type ram_type is array (FIFO_MAX_DEPTH-1 downto 0) of std_logic_vector (DWIDTH-1 downto 0);
  signal fifo            : ram_type := (others => (others => '0'));
  signal fifo_index_i    : signed (fifo_addr_width downto 0) := to_signed(-1, fifo_addr_width+1);
  signal fifo_empty      : boolean;
  signal fifo_full       : boolean;
  signal fifo_in_enable  : boolean;
  signal fifo_out_enable : boolean;
  signal fifo_almost_empty : std_logic;
  signal fifo_almost_full : std_logic;

  signal fifo_dout_internal : std_logic_vector(DWIDTH-1 downto 0);

begin
  fifo_full       <= (fifo_index_i = FIFO_MAX_DEPTH-1);  
  fifo_empty      <= (fifo_index_i = -1);
   
  --S_AXIS_TREADY   <= '1' when (not  fifo_full) else '0';
  S_AXIS_TREADY   <= '1' when (fifo_almost_full = '0') else '0';



  M_AXIS_TVALID  <= '1' when (not fifo_empty) else '0';
  --M_AXIS_TVALID   <= '1' when (fifo_almost_empty = '0') else '0';



  fifo_in_enable  <= (S_AXIS_TVALID  = '1') and (not fifo_full );
  fifo_out_enable <= (M_AXIS_TREADY = '1') and (not fifo_empty);
  
  fifo_dout_internal   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0))));  

  M_AXIS_TDATA <= fifo_dout_internal;

  fifo_almost_empty   <= '1' when (to_integer(fifo_index_i) <= FIFO_PROG_EMPTY) else '0';
  fifo_almost_full   <= '1' when (to_integer(fifo_index_i) >= FIFO_PROG_FULL -2 ) else '0';
  
  process (clk)
  begin
    if rising_edge(clk) then
      if fifo_in_enable then
        fifo <= fifo(FIFO_MAX_DEPTH-2 downto 0) & S_AXIS_TDATA;
        if not fifo_out_enable then fifo_index_i <= fifo_index_i + 1; end if;
      elsif fifo_out_enable then fifo_index_i <= fifo_index_i - 1;
      end if;
    end if;  
  end process;
 
end architecture;
