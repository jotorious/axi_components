-- ***************************************************************************
-- 01/26/2106
-- Joe McKinney
-- BIT Systems

-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity packet_rearrange is
	generic(
		RAMDEPTH : integer := 256
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
        din_rdy : out std_logic;
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_pkt_idx : out std_logic_vector(15 downto 0);
        dout_last : out std_logic;
        dout_rdy : in std_logic;
        
        pktlen : in std_logic_vector(15 downto 0);
        bins : in std_logic_vector(15 downto 0);
        samples_in  : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)
		);
end packet_rearrange;

architecture behav of packet_rearrange is

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

function bit_to_uint( bit_input : std_logic ) return integer is
    variable slv : std_logic_vector(0 downto 0);
    begin
        slv(0) := bit_input;
        return to_integer(unsigned(slv));
    end;

component packet_ram is
    generic (
        MDEPTH : integer
    );
    port(
      clk   : in  std_logic;
      ena   : in  std_logic;
      enb   : in  std_logic;
      wea   : in  std_logic;
      wr_addr : in  std_logic_vector(15 downto 0);
      rd_addr : in  std_logic_vector(15 downto 0);
      din   : in  std_logic_vector(31 downto 0);
      dout   : out std_logic_vector(31 downto 0)
    );
end component;


-----------------------------------
-- rename slv32
-----------------------------------  
type addr_array is array (0 to 1) of std_logic_vector(15 downto 0);
type data_array is array (0 to 1) of std_logic_vector(31 downto 0);

signal waddr, raddr : addr_array;
signal ram_din, ram_dout : data_array;

signal wr_addr : std_logic_vector(15 downto 0);

signal rd_addr : std_logic_vector(15 downto 0);

signal rd_out_idx : std_logic_vector(15 downto 0);

type data_dly_line is array (3 downto 0) of std_logic_vector(31 downto 0);

signal din_dly: data_dly_line;
signal din_en_dly : std_logic_vector (3 downto 0);

type addr_dly_line is array (3 downto 0) of std_logic_vector(15 downto 0);

signal waddr_dly : addr_dly_line;



signal write_selector, write_selector_thiscycle : integer range 0 to 1;
signal read_selector , read_selector_prev: integer range 0 to 1;

signal not_write_selector, not_write_selector_thiscycle : integer range 0 to 1;

signal ws_sl, ws_tc_sl, nws_tc_sl, rs_sl : std_logic;

signal mybad : std_logic;

signal wr_en : std_logic_vector( 0 to 1);

type type_ram_state is (EMPTY_BEING_FILLED, ALMOST_FULL, FULL_BEING_EMPTIED);
type state_array is array (0 to 1)of type_ram_state;
signal ram_state : state_array; 

signal r_addr_last : std_logic_vector(15 downto 0);

signal pktlen_minus_one : std_logic_vector(15 downto 0);

signal i_samples_in, i_samples_out : std_logic_vector(31 downto 0);

begin

-- Create integers to be used as array indexes
write_selector <= bit_to_uint(ws_sl);
write_selector_thiscycle <= bit_to_uint(ws_tc_sl);

not_write_selector <= bit_to_uint(not ws_sl);
nws_tc_sl <= not ws_tc_sl ;
not_write_selector_thiscycle <= bit_to_uint(nws_tc_sl);

mybad <= nws_tc_sl and ws_tc_sl;

read_selector <= bit_to_uint(rs_sl);



--in_last_sample <= '1' when din_en = '1' and (ram_state(1) = ALMOST_FULL) else '0';

ram_inst_0 : packet_ram
    generic map(
        MDEPTH => RAMDEPTH
    )
    port map (
        clk => clk,
        ena => '1',
        enb => '1',
        wea  => wr_en(0),
        wr_addr  => waddr(0),
        rd_addr  => raddr(0),
        din    => ram_din(0),
        dout    => ram_dout(0)
    );

ram_inst_1 : packet_ram
    generic map(
        MDEPTH => RAMDEPTH
    )
    port map (
        clk => clk,
        ena => '1',
        enb => '1',
        wea  => wr_en(1),
        wr_addr => waddr(1),
        rd_addr => raddr(1),
        din     => ram_din(1),
        dout    => ram_dout(1)
    );

dout <= ram_dout(0) when read_selector_prev = 0 else
        ram_dout(1) when read_selector_prev = 1 else
        x"00000000";

-- Can accept data when ram is not full and not almost full
din_rdy <=  '1' when (ram_state(0) = EMPTY_BEING_FILLED or ram_state(1) = EMPTY_BEING_FILLED ) else '0';

rw_proc: process(clk)
	begin
	if rising_edge(clk) then
        if rst = '0' then
            null;
            wr_en <= (others=>'0');
            wr_addr <= (others=>'0');
            rd_addr <= bins;
            rd_out_idx <= (others=>'0');

            -- This is 63, or 255, or 1023, or...
            pktlen_minus_one <= std_logic_vector(unsigned(pktlen) - 1);

            -- if bin = 4, then the last addr is 3
            -- if bin = 0, then the last addr is 1023
            if unsigned(bins) = 0 then
                r_addr_last <= std_logic_vector(unsigned(pktlen) - 1);
            else
                r_addr_last <= std_logic_vector(unsigned(bins) - 1) ;
            end if;
            ws_sl <= '0';
            rs_sl <= '0';

            ram_state(0) <= EMPTY_BEING_FILLED;
            ram_state(1) <= EMPTY_BEING_FILLED;
            dout_en <= '0';
            dout_last <= '0';
            din_en_dly <= ( others => '0');

            i_samples_in <= (others=>'0');
            i_samples_out <= (others=>'0');


        else
            -------------------------
            -- Write Side
            -------------------------


            -- Pipeline register for input data
            -- Note that input is only captured on data-enable
            din_dly(3 downto 1) <= din_dly(2 downto 0);
            din_en_dly (3 downto 1) <= din_en_dly(2 downto 0);

            -- For 1 clock/samp case, this drops the wr_en on the RAM not being written
            wr_en(not_write_selector_thiscycle) <= '0'; 

            -- On data-enable and RAM NOT FULL            
            if  ( (din_en = '1') and (ram_state(write_selector) /= FULL_BEING_EMPTIED)) then
                -- capture/delay data, enable, ram wr_addr, and the current write_selector                
                din_dly(0) <= din;
                din_en_dly(0) <= '1';
                waddr_dly(0) <= wr_addr;
                ws_tc_sl <= ws_sl;

                i_samples_in <= std_logic_vector(unsigned(i_samples_in) + 1);


                -- On Last sample, reset addr to 0, change the state to full, and change the write_selector
                if unsigned(wr_addr) = unsigned(pktlen_minus_one) then
                    wr_addr <= (others=>'0');
                    ram_state(write_selector) <= FULL_BEING_EMPTIED;
                    ws_sl <= not ws_sl;
                -- Otherwise, just increment address
                else
                    wr_addr <= std_logic_vector(unsigned(wr_addr) + 1 );
                end if;
            else
                din_dly(0) <= (others=>'0');
                din_en_dly(0) <= '0';
            end if;

            -- On the clock following the data-enable
            if din_en_dly(0) = '1' then
                -- Drive the data lines
                ram_din(write_selector_thiscycle) <= din_dly(0); 
                -- pulse WREN
                wr_en(write_selector_thiscycle) <= '1';
                waddr(write_selector_thiscycle) <= waddr_dly(0);
            else
                wr_en(write_selector_thiscycle) <= '0';
            end if;

            ----------------------
            --- Read Side
            ----------------------
            read_selector_prev <= read_selector;
            dout_pkt_idx <= rd_out_idx;

            if ((dout_rdy = '1') and (ram_state(read_selector) = FULL_BEING_EMPTIED ) )then
                dout_en <= '1';
                i_samples_out <= std_logic_vector(unsigned(i_samples_out) + 1);
                --read_selector_prev <= read_selector;
                -- Increment read address
                -- Addresses lead signals by a cycle
                if unsigned(rd_addr) = unsigned(pktlen_minus_one) then  -- Roll around
                    -- Reset to 0
                    rd_addr <= (others=>'0');
                    if unsigned(rd_out_idx) = unsigned(pktlen_minus_one) then -- this is a special case of eop that corresponds w/ roll around
                        rd_out_idx <= (others=>'0');
                        dout_last <= '1';
                        -- Set write lock on current RAM
                        ram_state(read_selector) <= EMPTY_BEING_FILLED;
                        -- Switch Read RAMS
                        rs_sl <= not rs_sl;
                    else
                        rd_out_idx <= std_logic_vector(unsigned(rd_out_idx) + 1);
                    end if;
                elsif unsigned(rd_addr) = unsigned(r_addr_last) then -- This is end-of-packet
                    rd_addr<= bins;
                    rd_out_idx <= (others=>'0');
                    dout_last <= '1';
                    -- Set write lock on current RAM
                    ram_state(read_selector) <= EMPTY_BEING_FILLED;
                    -- Switch Read RAMS
                    rs_sl <= not rs_sl;
                else
                    rd_addr <= std_logic_vector(unsigned(rd_addr) + 1 );
                    rd_out_idx <= std_logic_vector(unsigned(rd_out_idx) + 1);
                    dout_last <= '0';
                end if;
            else
                null; --waiting for the current ROM to be ready to read
                dout_en <= '0';
                dout_last <= '0';
            end if;

                

        end if;
    end if;
end process;


---
raddr(read_selector) <= rd_addr;
--dout_pkt_idx <= rd_out_idx;

samples_in <= i_samples_in;
samples_out <= i_samples_out;


  
end architecture;

