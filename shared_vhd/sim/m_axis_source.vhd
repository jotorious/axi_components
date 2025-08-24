----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/12/2018 12:02:15 PM
-- Design Name: 
-- Module Name: os_sbt_tb - Testbed
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use ieee.std_logic_textio.all;  
library std;
use STD.textio.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity m_axis_source is
    generic (
        PKTLEN : integer := 32;
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
end m_axis_source;

architecture Testbed of m_axis_source is

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

  -----------------------------------------------------------------------
  -- Timing constants
  -----------------------------------------------------------------------
  constant CLOCK_PERIOD : time := 2.5 ns;

  signal din : std_logic_vector(31 downto 0);
  signal din_en : std_logic := '0';
  signal din_last : std_logic := '0';
  signal din_user : std_logic_vector(15 downto 0);

  --constant CPS : integer := 8;

  ------------------------------------
  -- Stuff for getting external data
  ------------------------------------
  file outfile : text open write_mode is "Needle_INFILE2019.txt";  
  

  file infile : text open read_mode is infname;
  signal tb_xn_re, tb_xn_im		: std_logic_vector (15 downto 0);
  --signal tb_xk_re, tb_xk_im     : std_logic_vector (15 downto 0);

  signal samples_read_i : integer := 0;

  --constant PKTS_TO_SOURCE : integer := 8;
  constant EXTRA: integer := 0;
  constant SAMPLES_TO_SOURCE : integer := PKTS_TO_SOURCE *PKTLEN + EXTRA;

------------------------------------------------------------------------------
  type axis_bus is record
      tdata : std_logic_vector(31 downto 0);
      tuser : std_logic_vector(15 downto 0);
      tlast  : std_logic;
  end record axis_bus;

  constant axis_bus_init : axis_bus := (    tdata => (others=> '0'),
                                            tuser => (others=> '0'),
                                            tlast => '0');

  constant FIFO_MAX_DEPTH : integer := 8;
  constant FIFO_PROG_FULL : integer := 4;

  type RAM_AXISD is array ((FIFO_MAX_DEPTH-1) downto 0) of axis_bus;
  signal fifo : RAM_AXISD := (others => axis_bus_init);

  signal din_axis_bus : axis_bus;

  constant fifo_addr_width : integer := clog2(FIFO_MAX_DEPTH);

  signal fifo_index_i    : signed (fifo_addr_width downto 0) := to_signed(-1, fifo_addr_width+1);
  signal fifo_empty      : boolean;
  signal fifo_full_i     : boolean;
  signal fifo_full_sl    : std_logic;
  signal fifo_almost_full    : std_logic;
  signal fifo_in_enable  : boolean;
  signal fifo_out_enable : boolean;
  signal debug_raddr : integer;



begin

------------------------
--Data in process
------------------------

td_proc: process(M_AXIS_ACLK) 
variable count : integer range 0 to CPS;
variable s_count : integer range 0 to PKTLEN;
variable file_count : integer;

variable inline: line;
variable vvalid: boolean;
variable indata: std_logic_vector(15 downto 0);

begin

if rising_edge(M_AXIS_ACLK) then
    if M_AXIS_ARESETN = '0' then
        count := 0;
        s_count := 0;
        file_count := 0;
        tb_xn_re <= (others=>'0');
        tb_xn_im <= (others=>'0');
        din_en <= '0';
        din_last <= '0';
        din_user <= (others=> '0');
        samples_read_i <= 0;
    else
        count := count + 1;
        if (count = CPS) then
            count := 0;
        end if;
        -- Every X clks, if the Fifo isn't full, put new data up, and pulse the enable
        --if ((count = 0) and (fifo_full_sl = '0')) then
        if ((count = 0) and (fifo_almost_full = '0')) then
            ----------------------
            -- Read Data from File
            ----------------------

            --din <= std_logic_vector(unsigned(din) + 1);
            if (not endfile(infile)) and (file_count < SAMPLES_TO_SOURCE)  then
                readline(infile,inline);
                hread(inline,indata);
                tb_xn_re <= indata;
                readline(infile,inline);
                hread(inline,indata);
                tb_xn_im <= indata;
                din_en <= '1';
                din_user <=  std_logic_vector(to_unsigned(s_count,16));
                s_count := s_count + 1;
                file_count := file_count + 1;
                if (s_count = PKTLEN) then
                    din_last <= '1';
                    s_count := 0;
                else
                    din_last <= '0';
                end if;
            else
                report "input file done";
                din_en <= '0';
                din_last <= '0';
                din_user <= (others=> '0');
            end if;
        else
            din_en <= '0';
        end if;
        samples_read_i <= file_count;
    end if;
end if;
end process;

--din(15 downto 0) <= tb_xn_re;
din(15 downto 0) <= x"0002";
din(31 downto 16) <= tb_xn_im;

samples_read <= samples_read_i;


-------------------------------------------------
-- This TB code is intended to isolate the M_AXIS signals 
-- from the upstream dataflow. 
------------------------------------------------------

  din_axis_bus.tdata <= din;
  din_axis_bus.tlast <= din_last;
  din_axis_bus.tuser <= din_user;

  fifo_empty      <= (fifo_index_i = -1);
  fifo_full_i       <= (fifo_index_i = FIFO_MAX_DEPTH-1);

  fifo_full_sl   <= '1' when (fifo_full_i) else '0';
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

end Testbed;
