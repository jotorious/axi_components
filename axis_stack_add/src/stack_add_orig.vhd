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

entity stack_add is
	generic(
		PKTLENIN : integer := 256;
        PKTLENOUT : integer := 32
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic);
end stack_add;

architecture behav of stack_add is

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
-- Types and subtypes
-----------------------------------  
subtype slv32 is STD_LOGIC_VECTOR(31 DOWNTO 0);
type slv16_array is array (0 to 3) of std_logic_vector(15 downto 0);
type slv32_array is array (0 to 3) of std_logic_vector(31 downto 0);

type complex_slv16 is record
    i : std_logic_vector(15 downto 0);
    q : std_logic_vector(15 downto 0);
end record complex_slv16;

type complex_slv32 is record
    i : std_logic_vector(31 downto 0);
    q : std_logic_vector(31 downto 0);
end record complex_slv32;

type type_cmplx_din_dly is array (0 to 3) of complex_slv16;
----------------------------
-- constants
----------------------------
constant pktin_addr_width : integer := clog2(PKTLENIN);
constant pktout_addr_width : integer := clog2(PKTLENOUT);
constant pkt_ratio : integer := pktin_addr_width - pktout_addr_width;

-- This is a set of zeros
constant pkt_addr_pad : std_logic_vector(15 - pktout_addr_width downto 0) := (others =>'0');
constant pkt_csel_zeros : std_logic_vector(pktin_addr_width - pktout_addr_width -1 downto 0) := (others =>'0');


constant pktlenin_minus_one_slv : std_logic_vector(pktin_addr_width - 1 downto 0) := std_logic_vector(to_unsigned(PKTLENIN - 1,pktin_addr_width));
constant pktlenout_minus_one_slv : std_logic_vector(pktout_addr_width - 1 downto 0) := std_logic_vector(to_unsigned(PKTLENOUT - 1,pktout_addr_width));

constant pktlenout_zeros_slv : std_logic_vector(pktout_addr_width - 1 downto 0) := (others => '0');

--------------------------------------------
-- Memory signals
--------------------------------------------
signal waddr, raddr : slv16_array;

signal ram_ren: std_logic_vector(0 to 3);
signal ram_wen: std_logic_vector(0 to 3);

signal ram_dout, ram_din : slv32_array;

--------------------------------------------
-- Input side (add-accumulate) signals
--------------------------------------------

signal w_sind : std_logic_vector(pktin_addr_width - 1 downto 0);
signal w_pkt_sel : std_logic;

signal r_sind : std_logic_vector(pktin_addr_width - 1  downto 0);
signal r_pkt_sel : std_logic;

signal w_sind_short : std_logic_vector(pktout_addr_width - 1 downto 0);
signal r_sind_short : std_logic_vector(pktout_addr_width - 1  downto 0);

signal r_sind_short_prev : std_logic_vector(pktout_addr_width - 1  downto 0);
signal r_sind_short_prev_eq_ones     : boolean;
signal r_sind_short_eq_zeros     : boolean;

signal w_sind_csel : std_logic_vector(pktin_addr_width - pktout_addr_width -1 downto 0);
signal r_sind_csel : std_logic_vector(pktin_addr_width - pktout_addr_width -1 downto 0);

signal waddr_ip : std_logic_vector(15 downto 0);
signal raddr_ip : std_logic_vector(15 downto 0);
signal ram_ren_all : std_logic;
signal ram_wen_all : std_logic;

signal ram_ren_all_dly : std_logic_vector(0 to 3);
signal ram_wen_all_dly : std_logic_vector(0 to 3);

signal read_ready : std_logic_vector(0 to 1);

signal din_dly : type_cmplx_din_dly;

signal r_pkt_sel_dly : std_logic_vector( 0 to 3);

signal accum_out : complex_slv32;
signal accum_ip : complex_slv32;


signal dout_en_internal : std_logic;
signal dout_last_internal : std_logic;

signal dout_tuser_internal, dout_tuser_internal_dly : std_logic_vector(15 downto 0) := (others=> '0');

signal blah, blah_dly : std_logic;

----------------------
-- Register out side signals
----------------------

signal register_out : complex_slv32;
constant register_in : std_logic_vector(31 downto 0) := (others=> '0');

begin

--pkt_addr_pad <= (others =>'0');
r_sind_short <= r_sind(pktout_addr_width - 1 downto 0);
w_sind_short <= w_sind(pktout_addr_width - 1 downto 0);

r_sind_csel <= r_sind(pktin_addr_width -1  downto pktout_addr_width);
w_sind_csel <= w_sind(pktin_addr_width -1  downto pktout_addr_width);

-- This is what the input side processing does
waddr_ip <= pkt_addr_pad & w_sind_short;
raddr_ip <= pkt_addr_pad & r_sind_short;


-- on read side, 

accum_out.i <= ram_dout(0) when r_pkt_sel_dly(0) = '0' else
               ram_dout(1);
register_out.i <= ram_dout(0) when r_pkt_sel_dly(0) = '1' else
               ram_dout(1);

accum_out.q <= ram_dout(2) when r_pkt_sel_dly(0) = '0' else
               ram_dout(3);
register_out.q <= ram_dout(2) when r_pkt_sel_dly(0) = '1' else
               ram_dout(3);


-- on write side,

ram_din(0) <= accum_ip.i when w_pkt_sel = '0' else
            register_in;

ram_din(1) <= accum_ip.i when w_pkt_sel = '1' else
            register_in;

ram_din(2) <= accum_ip.q when w_pkt_sel = '0' else
            register_in;

ram_din(3) <= accum_ip.q when w_pkt_sel = '1' else
            register_in;

waddr(0) <= waddr_ip;
waddr(1) <= waddr_ip;
waddr(2) <= waddr_ip;
waddr(3) <= waddr_ip;

raddr(0) <= raddr_ip;
raddr(1) <= raddr_ip;
raddr(2) <= raddr_ip;
raddr(3) <= raddr_ip;

ram_ren(0) <= ram_ren_all;
ram_ren(1) <= ram_ren_all;
ram_ren(2) <= ram_ren_all;
ram_ren(3) <= ram_ren_all;

ram_wen(0) <= ram_wen_all;
ram_wen(1) <= ram_wen_all;
ram_wen(2) <= ram_wen_all;
ram_wen(3) <= ram_wen_all;



packet_out_ram_inst0 : packet_ram
    generic map(
        MDEPTH => PKTLENOUT*2
    )
    port map (
        clk => clk,
        ena => ram_wen(0),
        enb => ram_ren(0),
        wea  => '1',
        wr_addr  => waddr(0),
        rd_addr  => raddr(0),
        din    => ram_din(0),
        dout    => ram_dout(0)
    );

packet_out_ram_inst1 : packet_ram
    generic map(
        MDEPTH => PKTLENOUT*2
    )
    port map (
        clk => clk,
        ena => ram_wen(1),
        enb => ram_ren(1),
        wea  => '1',
        wr_addr  => waddr(1),
        rd_addr  => raddr(1),
        din    => ram_din(1),
        dout    => ram_dout(1)
    );

packet_out_ram_inst2 : packet_ram
    generic map(
        MDEPTH => PKTLENOUT*2
    )
    port map (
        clk => clk,
        ena => ram_wen(2),
        enb => ram_ren(2),
        wea  => '1',
        wr_addr  => waddr(2),
        rd_addr  => raddr(2),
        din    => ram_din(2),
        dout    => ram_dout(2)
    );

packet_out_ram_inst3 : packet_ram
    generic map(
        MDEPTH => PKTLENOUT*2
    )
    port map (
        clk => clk,
        ena => ram_wen(3),
        enb => ram_wen(3),
        wea  => '1',
        wr_addr  => waddr(3),
        rd_addr  => raddr(3),
        din    => ram_din(3),
        dout    => ram_dout(3)
    );





ip_proc: process(clk)
	begin
	if rising_edge(clk) then
        if rst = '0' then
            w_sind <= (others =>'1');
            r_sind <= (others =>'1');
            w_pkt_sel <= '1';
            r_pkt_sel <= '1';
            ram_ren_all <= '0';
            ram_wen_all <= '0';
            read_ready <= (others => '0');

            accum_ip.i <= (others => '0');
            accum_ip.q <= (others => '0');
        else
            r_pkt_sel_dly(0) <= r_pkt_sel;

            din_dly(1 to 3) <= din_dly(0 to 2);

            ram_ren_all_dly(0) <= ram_ren_all;
            ram_ren_all_dly(1 to 3) <= ram_ren_all_dly(0 to 2);
            ram_wen_all_dly(0) <= ram_wen_all;
            ram_wen_all_dly(1 to 3) <= ram_wen_all_dly(0 to 2);

            -------------------------
            -- Input Data   - input driven
            ------------------------
            if din_en = '1' then
                
                -- Clock data into register
                din_dly(0).i <= din(15 downto 0);
                din_dly(0).q <= din(31 downto 16);
                -- Increment Address;

                -- On Last Read Address
                if r_sind = pktlenin_minus_one_slv then
                    -- reset to 0                    
                    r_sind <= (others => '0');
                    -- switch read packet selector                     
                    r_pkt_sel <= not r_pkt_sel ;
                    -- Capture Ready 
                    if read_ready(0) = '1' then
                        read_ready(1) <= '1';
                    end if;
                else
                    r_sind <= std_logic_vector(unsigned(r_sind) + 1 );
                end if;
                -- Raise REN
                ram_ren_all <= '1';

            else
                -- Lower REN
                ram_ren_all <= '0';
            end if;
            
            if ram_ren_all_dly(0) = '1' then
                -- RAM DOUT is valid after the last edge, so add the input, and clk into a register on this edge
                                
                accum_ip.i <= std_logic_vector(resize(signed(din_dly(1).i),accum_ip.i'length) + signed(accum_out.i));
                accum_ip.q <= std_logic_vector(resize(signed(din_dly(1).q),accum_ip.q'length) + signed(accum_out.q));

                -- Incr write adder
                if w_sind = pktlenin_minus_one_slv then
                    w_sind <= (others => '0');
                    w_pkt_sel <= not w_pkt_sel ;
                    read_ready(0) <= '1';
                else
                    w_sind <= std_logic_vector(unsigned(w_sind) + 1 );
                end if;

                -- Raise WEN
                ram_wen_all <= '1';                
            else
                -- Lower WEN
                ram_wen_all <= '0';
            end if;
        end if;
    end if;
end process;

dout_en <= dout_en_internal ;
dout_last <= dout_last_internal;
dout_tuser_internal(pktout_addr_width - 1  downto 0) <= r_sind_short_prev;


-- This is every REN = '1' while ADDR is 00XXXXX
blah <= '1' when (r_sind_csel = pkt_csel_zeros and read_ready = "11") and(ram_ren_all = '1') else '0';

r_sind_short_prev_eq_ones   <= (r_sind_short_prev = pktlenout_minus_one_slv);
r_sind_short_eq_zeros       <= (r_sind_short = pktlenout_zeros_slv);

op_proc: process (clk)
    begin
    if rising_edge(clk)then
        if rst ='0' then
            dout <= (others => '0');
            dout_en_internal <= '0';
            dout_last_internal <= '0';
        else
            blah_dly <= blah;
            r_sind_short_prev <= r_sind_short;
            
            dout_tuser_internal_dly <= dout_tuser_internal;
            if blah_dly = '1' then
                dout_en_internal <= '1';
                dout(15 downto 0) <= register_out.i(15 + pkt_ratio downto 0 + pkt_ratio );
                dout(31 downto 16) <= register_out.q(15 + pkt_ratio downto 0 + pkt_ratio );
                if r_sind_short_prev_eq_ones then
                    dout_last_internal <= '1';    
                else
                    dout_last_internal <= '0';
                end if;
            else
                dout_en_internal <= '0';
                dout_last_internal <= '0';
            end if;
        end if;
    end if;
end process;

  
end architecture;

