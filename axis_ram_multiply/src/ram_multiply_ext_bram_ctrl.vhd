-- ***************************************************************************
-- 03/29/2019
-- Joe McKinney
-- BIT Systems

-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity ram_multiply_ext_bram_ctrl is
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
end ram_multiply_ext_bram_ctrl;

architecture behav of ram_multiply_ext_bram_ctrl is

component cmpy_0
  Port ( 
    aclk : in STD_LOGIC;
    aresetn : in STD_LOGIC;
    s_axis_a_tvalid : in STD_LOGIC;
    s_axis_a_tuser : in STD_LOGIC_VECTOR ( 23 downto 0 );
    s_axis_a_tlast : in STD_LOGIC;
    s_axis_a_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_b_tvalid : in STD_LOGIC;
    s_axis_b_tlast : in STD_LOGIC;
    s_axis_b_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    m_axis_dout_tvalid : out STD_LOGIC;
    m_axis_dout_tuser : out STD_LOGIC_VECTOR ( 23 downto 0 );
    m_axis_dout_tlast : out STD_LOGIC;
    m_axis_dout_tdata : out STD_LOGIC_VECTOR ( 63 downto 0 )
  ); 
END COMPONENT;

component dual_port_ram
    generic (
        depth : integer := 2048;
		data_in_file: string    := "filter_coefs.data" 
	);
    port(
        clka  : in  std_logic;
        clkb  : in  std_logic;
        ena   : in  std_logic;
        enb   : in  std_logic;
        wea   : in  std_logic;
        web   : in  std_logic;
        addra : in  std_logic_vector(31 downto 0);
        addrb : in  std_logic_vector(31 downto 0);
        dina   : in  std_logic_vector(31 downto 0);
        dinb   : in  std_logic_vector(31 downto 0);
        douta   : out std_logic_vector(31 downto 0);
        doutb   : out std_logic_vector(31 downto 0)
    );
end component;




--delay lines for input
type din_reg_t is array (0 to 1) of std_logic_vector(31 downto 0);
signal din_dly : din_reg_t;
signal din_en_dly  : std_logic_vector(0 to 1);
signal din_last_dly: std_logic_vector(0 to 1);
type dinuser_reg_t is array (0 to 1) of std_logic_vector(23 downto 0);
signal din_user_dly : dinuser_reg_t;

-- slices
signal fft_xk_index : std_logic_vector(11 downto 0);
signal rom_addr : std_logic_vector(31 downto 0) := (others=>'0');


signal rom_data : std_logic_vector(31 downto 0) := (others=>'0');

signal rom_last_addr : std_logic := '0';
signal rom_last_data : std_logic := '0';

signal mult_dout_dlong : std_logic_vector(63 downto 0);
signal mult_dout_last : std_logic;
signal mult_dout_en : std_logic;
signal mult_dout_user : std_logic_vector(23 downto 0);

constant cmpy_bg : integer := 1;
signal cmpy_shift : integer range 0 to Nfft;

signal i_counter_in, i_counter_out :std_logic_vector(31 downto 0);

signal test_rom_q, test_rom_i, test_data_q, test_data_i : std_logic_vector(15 downto 0);

--RAM ctrl interface signals
--signal bram_rst : std_logic;
--signal bram_clk :STD_LOGIC;
--signal bram_en : STD_LOGIC;
--signal bram_we: STD_LOGIC_VECTOR(3 DOWNTO 0);
--signal bram_addr : STD_LOGIC_VECTOR(12 DOWNTO 0);

--signal bram_addr_long : STD_LOGIC_VECTOR(31 DOWNTO 0);
--signal bram_wrdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
--signal bram_rddata : STD_LOGIC_VECTOR(31 DOWNTO 0);

begin

counter_in <= i_counter_in;
counter_out <= i_counter_out;


regin_proc:process(clk)
begin
if rising_edge(clk) then
    if rstn = '0' then
        din_dly <= (others=>(others=>'0'));
        din_en_dly <= (others=>'0');
        din_last_dly <= (others=>'0');
        din_user_dly <= (others=>(others=>'0'));
        rom_last_data <= '0';
        i_counter_in <= (others=>'0');
    else
        if din_en = '1' then
            i_counter_in <= std_logic_vector(unsigned(i_counter_in) + 1);

            din_dly(0)      <= din;
            din_en_dly(0)   <= din_en;
            din_last_dly(0) <= din_last;
            din_user_dly(0) <= din_user;
        else
            din_en_dly(0)<= '0';
        end if;
            
        if din_en_dly(0) = '1' then      
            din_dly(1)      <= din_dly(0);
            din_en_dly(1)   <= din_en_dly(0);
            din_last_dly(1) <= din_last_dly(0);
            din_user_dly(1) <= din_user_dly(0);

            rom_last_data <= rom_last_addr;
        else
            din_en_dly(1) <= '0';
        end if;

        
    end if;
end if;
end process;

---------------------------------------------------------
-- Filter Coefficients in the Frequency Domain
-- are inplemented as a ROM. This could be implemented as
-- a Loadable RAM, in which case the response would be runtime 
-- Adjustable
-- As it is now, at Design time, I generate the coefs in python and write them
-- to a file, and that file as see below is read at compile time.
-- The filter file contains 16 Bits of I and 16 Bits of Q, written as a
-- single 32 bit word, accessed by a single read address/ strobe 

---------------------------------------------------------

-- All I'm doing here is looking up a piece of data
-- ##As implemented, I did minimal verification of how this works when
-- Axi-S is throttle by the downstream. I think it's OK, because in regards
-- to data flow and control, the ROM setup and mult just look like delays/pipelines

fft_xk_index <= din_user_dly(0)(11 downto 0);
rom_addr <= x"00000" & fft_xk_index;

---THIS WAS FOR DEBUGrom_addr <= x"00000000";
rom_last_addr <= '1' when rom_addr = std_logic_vector(to_unsigned(Nfft-1,32)) else '0';


filter_freq_coefs: dual_port_ram 
    generic map (
        depth => Nfft,
        data_in_file => filter_file
    )
    port map (
        clka => clk,
        clkb => bram_clk,
        ena  => din_en_dly(0),
        enb  => bram_en,
        wea  => '0',
        web  => bram_we(3),
        addra => rom_addr,
        addrb => bram_addr_long,
        dina  => (others=>'0'),
        dinb  => bram_wrdata,
        douta => rom_data,
        doutb => bram_rddata
    );


--bram_addr is 13 bit Byte address
-- so the 11 bit word address is bram_addr(bram_addr'left downto bram_addr'right+2)
bram_addr_long <= x"00000" & '0' & bram_addr(12 downto 2);

test_rom_i <= rom_data(15 downto 0);
test_rom_q <= rom_data(31 downto 16);
---------------------------------------------------------
-- Delay Forward FFT outputs 1 Clock,
-- because I use the Xk data as an address to the ROM,
-- and the ROM takes 1 clock to drive the data lines from
-- the specified address.
---------------------------------------------------------

-- FFT Dout is:
--         -----------------------------
-- tdata   X  Coef 0  X  Coef 1  X  Coef 2
--         -----------------------------
-- tuser   X    0     X    1     X    2
--         -------------------------------

-- ROM Dout is:
--         ---------------------------------------
-- data    X        Coef 0       X  Coef 1  X Coef 2
--         ---------------------------------------
-- addr    X    0     X    1     X   2      X   3
--         ---------------------------------------

-- The ROM takes 1 clock to turn address into data
-- The ROM ADDR is fft_dout.tuser, which is Freq Bin
-- So to line up operands at Mult input delay FFT output data by 1 clk cyclk


---------------------------------------------------------
-- Complex Multiplier
---------------------------------------------------------

-- There are no TREADYS on this core as configured.

test_data_i <= din_dly(1)(15 downto 0);
test_data_q <= din_dly(1)(31 downto 16);
    
cmpy_inst : cmpy_0
  PORT MAP (
    aclk => clk,
    aresetn => rstn,
    s_axis_a_tvalid => din_en_dly(1),
    s_axis_a_tuser => din_user_dly(1),
    s_axis_a_tlast => din_last_dly(1),
    s_axis_a_tdata => din_dly(1),
    
    s_axis_b_tvalid => din_en_dly(1),
    s_axis_b_tlast => rom_last_data,
    s_axis_b_tdata => rom_data,
    
    m_axis_dout_tvalid => mult_dout_en,
    m_axis_dout_tuser => mult_dout_user,
    m_axis_dout_tlast => mult_dout_last,
    m_axis_dout_tdata => mult_dout_dlong
  );
  
 -- IMAG is 63 to 32
 -- REAL is 31 to 0

-- Natural width is 33 each truncate to 32 drops the LSB
-- A+jB * C+jD = AC-BD + j(BC+AD)
-- AC is 1.15 x 1.15 = 2.30, AC + BD is then 3.30
-- drop the LSB and you have 3.29
-- which means if you are smart you choose 2 bits down?

-- There is something I don't understand, because I had to set cmpybg=1

 dout_last <= mult_dout_last;
 dout_en   <= mult_dout_en;
 dout_user <= mult_dout_user;
 dout(31 downto 16) <= mult_dout_dlong(63-cmpy_bg downto 48-cmpy_bg);
 dout(15 downto 0)  <= mult_dout_dlong(31-cmpy_bg downto 16-cmpy_bg);

cnt_proc:process(clk,rstn)
begin
    if rising_edge(clk) then
        if rstn = '0' then
            i_counter_out <= (others=>'0');
        else
            if mult_dout_en = '1' then
                i_counter_out <= std_logic_vector(unsigned(i_counter_out) + 1);
            end if;
        end if;
    end if;
end process;

-----------------
-- The multipler has 6 cycles of latency, which means if I pulse the input enable,
-- 6 clocks later the output enable pulses.
-- The ROM has 1 cycle of latency.
-- the input register has 1 cycle of latency


-- For downstream originated back-pressure, this means that the downstream fifo needs 
-- enough space, that when it indicates Almost Full, it can ingest at least all the possible samples
-- already in the pipeline. For full sample rate, this means that the input enable has been high
-- for the observable past. The downstream fifo signals almost-full at time X. This drops the input
-- enable, stopping the ingestion of samples. But in this scenario, there are 8 samples, already
-- ingested and in the pipeline that are going to egress. The fifo has to capture these. 

-- Almost full drops --> input enable rises, it takes 8 clocks for any data to comeout, so
-- Almost full stays at 0, input enable stays at 1 for 8 clocks
-- then output enable goes high and samples start coming out.
-- when enough samples come out, Almost full goes high, input enable drops. 

  
end architecture;

