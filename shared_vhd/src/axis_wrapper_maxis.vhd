library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- I modified this from an open-source example on the internet, after having alot of trouble implementing
-- this functionality using a RAM based approach. Writing Software for 3 years has made me soft. Logic is King. 

-- When using this wrapper, the programmable full generic is used to specify when when
-- the almost full signal goes high. This is important.

-- The full or almost full signals are fed back and gated with the enable input of
-- ones' logic block. The time it takes between that enable input going low and data to stop
-- coming out of the output determines the amount of space you must reserve in the fifo.
-- for example. if you are running at a clock per sample, and your logic has 3 pipelined states,
-- when you drop the enable input, your logic necessarily stops consuming data, and depending on
-- your design might output the 3 output samples that it had already started working. In this case,
-- youd want the delta between the fifo depth and programmable full to be at least 3. So, if the
-- depth was 8 and prog full was 4, then when the depth hits 4, the almost_full signal goes high, the 
-- upstream logic block stops consuming data, and the 3 samples being worked on when the enable went low,
-- are clocked out and captured into the fifo.

-- This is a function of how your flow control works. If you have sample in, sample out with full pipelining;
-- implying that data input and enable starts your processing and all subsequent control is internally derived
-- then you need how ever many internal states/samples. If it's something more unpleasant like, for example,
-- a single sample in, and say X samples out, without any sort of pipelining, you'd need space for X samples.

-- Also, making this even more ridiculous is cascading blocks, and, when necessary, dealing with the amount
-- of time it takes for the full/almost_full feedback to ripple back. If your logic is large enough that you
-- have to add registers to the feedback path, now it's that internal state depth plus the number of clocks
-- full/almost full back to enable side. Suppose your logic has 3 pipeline states and it takes 4 clocks to get
-- the full/ almost_full back to the enable side. The 3 pipeline states mean that you go full on the output and
-- in 1 clk cycle feed it back and drop the enable. So there are 3 samples that are going to come out. Great.
-- but if it take 4 clocks to get the enable to drop, you will get 3 + 4 = 7 samples after the almost_full goes high.

-- If your upstream is running a sample at a time, then if it takes a cycle to get the full signal fed back to stop
-- upstream, it's already too late, you've lost a sample. Use the almost full signal.

-- TODO: look at drving zeros when the FIFO is empty. This would entail not ever shifting data into highest address and controlling
-- the fifo to stop so that it only reads from that address when empty. This might cause inference of LUTS and FF's instead of SRLs


entity axis_wrapper_maxis is
    generic (
	    -- Width of M_AXIS address bus. 
	    C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
        -- Max Fifo Depth
        FIFO_MAX_DEPTH : integer range 2 to 32 := 16;
        -- Programmable Full Threshold
        FIFO_PROG_FULL : integer range 2 to 32 := 8
    );
    port (
        din : in std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
        din_en : in std_logic;
        din_last : in std_logic;
        din_user : in std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
        fifo_full : out std_logic;
        fifo_almost_full : out std_logic;
		-- Global ports
		M_AXIS_ACLK	: in std_logic;
		M_AXIS_ARESETN	: in std_logic;
		 
		M_AXIS_TVALID	: out std_logic;
		M_AXIS_TREADY	: in std_logic;
        M_AXIS_TDATA	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
        M_AXIS_TUSER	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		M_AXIS_TSTRB	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		M_AXIS_TLAST	: out std_logic	
    );
end axis_wrapper_maxis;

architecture arch of axis_wrapper_maxis is

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
      tdata : std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
      tuser : std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
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
  signal fifo_empty      : boolean;
  signal fifo_full_i     : boolean;
  signal fifo_in_enable  : boolean;
  signal fifo_out_enable : boolean;
  signal debug_raddr : integer;

  

begin

  din_axis_bus.tdata <= din;
  din_axis_bus.tlast <= din_last;
  din_axis_bus.tuser <= din_user;

  fifo_empty      <= (fifo_index_i = -1);
  fifo_full_i       <= (fifo_index_i = FIFO_MAX_DEPTH-1);

  fifo_full   <= '1' when (fifo_full_i) else '0';
  fifo_almost_full   <= '1' when (to_integer(fifo_index_i) >= FIFO_PROG_FULL -2 ) else '0';
  
  fifo_in_enable  <= (din_en  = '1') and (not fifo_full_i );
  fifo_out_enable <= (M_AXIS_TREADY = '1') and (not fifo_empty);

  M_AXIS_TVALID  <= '1' when (not fifo_empty) else '0';
  M_AXIS_TDATA   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tdata; 
  M_AXIS_TUSER   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tuser; 
  M_AXIS_TLAST   <= fifo(to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)))).tlast;

  debug_raddr <= to_integer(unsigned(fifo_index_i(fifo_addr_width -1 downto 0)));

  M_AXIS_TSTRB <= (others=> '0');
  -- Implement a Shift Register
  process (M_AXIS_ACLK)
  begin
    if rising_edge(M_AXIS_ACLK) then
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

 process (M_AXIS_ACLK)
  begin
    if rising_edge(M_AXIS_ACLK) then
      if fifo_in_enable then
        if not fifo_out_enable then
            fifo_index_i <= fifo_index_i + 1;
        end if;
      elsif fifo_out_enable then
        fifo_index_i <= fifo_index_i - 1;
      end if;
    end if;  
  end process;

--  process (M_AXIS_ACLK)
--  begin
--    if rising_edge(M_AXIS_ACLK) then
--      if fifo_in_enable then
--        fifo(FIFO_MAX_DEPTH-1 downto 1) <= fifo(FIFO_MAX_DEPTH-2 downto 0);
--        fifo(0).tdata                   <= din;
--        fifo(0).tlast                   <= din_last;
--
--        if not fifo_out_enable then
--            fifo_index_i <= fifo_index_i + 1;
--        end if;
--      elsif fifo_out_enable then
--        fifo_index_i <= fifo_index_i - 1;
--      end if;
--    end if;  
--  end process;


 
end architecture;
