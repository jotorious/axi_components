-- ***************************************************************************
-- 01/26/2106
-- Joe McKinney
-- BIT Systems
-- 
-- created by discarding the first P-1 samples of an N sample long frame
--
-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity mag_squ_tb is
end mag_squ_tb;

architecture testbed of mag_squ_tb is

component mag_squared is
	port(
		clk : IN STD_LOGIC;
        rstn : IN STD_LOGIC;
        
        din : in std_logic_vector(31 downto 0);
        din_en : in std_logic;
        din_last : in std_logic;
        din_user : in std_logic_vector(15 downto 0);
        
        dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(15 downto 0);
        dout : out std_logic_vector(31 downto 0)
		);
end component;

signal tb_din_a, tb_din_b, tb_dout_short, tb_din_user, tb_dout_user : std_logic_vector(15 downto 0);
signal tb_dout : std_logic_vector(31 downto 0);

signal clk, rstn, tb_din_en, tb_dout_en, tb_din_last, tb_dout_last, clken : std_logic;

constant CLOCK_PERIOD : time := 10 ns;

signal tb_data32 : std_logic_vector(31 downto 0);

--Quick and Dirty Sine wave generation

--from numpy import *
--t = arange(0,.000001,0.00000001)
--s= 8000*sin(2*pi*1000000*t)
--s=s.astype(int)
--len(s)

type ram_type is array (0 to 99) of integer range -32768 to 32767;

signal sinewave : ram_type := (
        0,   2009,   4010,   5996,   7958,   9888,  11779,  13624,
        15416,  17146,  18809,  20397,  21905,  23326,  24656,  25888,
        27018,  28041,  28954,  29752,  30433,  30994,  31433,  31747,
        31936,  32000,  31936,  31747,  31433,  30994,  30433,  29752,
        28954,  28041,  27018,  25888,  24656,  23326,  21905,  20397,
        18809,  17146,  15416,  13624,  11779,   9888,   7958,   5996,
         4010,   2009,      0,  -2009,  -4010,  -5996,  -7958,  -9888,
       -11779, -13624, -15416, -17146, -18809, -20397, -21905, -23326,
       -24656, -25888, -27018, -28041, -28954, -29752, -30433, -30994,
       -31433, -31747, -31936, -32000, -31936, -31747, -31433, -30994,
       -30433, -29752, -28954, -28041, -27018, -25888, -24656, -23326,
       -21905, -20397, -18809, -17146, -15416, -13624, -11779,  -9888,
        -7958,  -5996,  -4010,  -2009);


begin

clk_proc: process
	begin
		wait for CLOCK_PERIOD/2;
		clk <= '1';
		wait for CLOCK_PERIOD/2;
		clk <= '0';
end process;

rst_proc: process
	begin
		wait for 4* CLOCK_PERIOD;
		rstn <= '0';
		wait for 6*CLOCK_PERIOD;
		rstn <= '1';
		wait;
end process;



clken_proc: process(clk)
variable count : integer;
begin
    if rising_edge(clk) then
        if rstn = '0' then
            count := 0 ;
            clken <= '0';
        else
            count := count + 1;
            if count = 4 then
                count := 0;
                clken <= '1';
            else
                clken <= '0';
            end if;
        end if;
    end if;
end process;


tb_dout_short <= tb_dout(31 downto 16); 

main_proc: process(clk)
variable swi : integer:= 0;
begin
	if rising_edge(clk) then
        if rstn = '0' then
            tb_din_a <= (others => '0');
            tb_din_b <= (others => '0');
            tb_din_en <= '0' ;
            tb_din_last <= '0';
        else
            if clken = '1' then
                if signed(tb_din_a) = 32767 then
                    tb_din_en <= '0';
                else
                    --tb_din_a <= std_logic_vector(signed(tb_din_a) + 1);
                    --tb_din_b <= std_logic_vector(signed(tb_din_b) + 1);
                    swi := swi + 1;
                    if swi = 100 then
                        swi:= 0;
                        tb_din_last <= '1';
                    else
                        tb_din_last <= '0';
                    end if;
                    tb_din_a <= std_logic_vector(to_signed(sinewave(swi),tb_din_a'length));
                    tb_din_b <= std_logic_vector(to_signed(sinewave(swi),tb_din_b'length));                    
                    tb_din_en <= '1';
                end if;
            else
                tb_din_en <= '0';
            end if;
        end if;
	end if;
end process;

tb_data32 <= tb_din_a & tb_din_b;

DUT: mag_squared
        port map (
            clk     => clk,
            rstn    => rstn,
            din   => tb_data32,
            din_last   => tb_din_last,
            din_user => tb_din_user,
            din_en  => tb_din_en,
            dout_en => tb_dout_en,
            dout    => tb_dout,
            dout_last => tb_dout_last,
            dout_user => tb_dout_user
            ); 
end architecture;

