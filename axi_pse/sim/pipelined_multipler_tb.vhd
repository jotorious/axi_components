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

entity pipelined_mult_tb is
end pipelined_mult_tb;

architecture testbed of pipelined_mult_tb is

component pipelined_multiplier
	port(
		clk : IN STD_LOGIC;
        rstn : IN STD_LOGIC;
        din_a : in std_logic_vector(15 downto 0);
        din_b : in std_logic_vector(15 downto 0);
        din_en: in std_logic;
        dout_en : out std_logic;
        dout : out std_logic_vector(31 downto 0)
        );
end component;

signal tb_din_a, tb_din_b, tb_dout_short : std_logic_vector(15 downto 0);
signal tb_dout : std_logic_vector(31 downto 0);

signal clk, rstn, tb_din_en, tb_dout_en, clken : std_logic;

constant CLOCK_PERIOD : time := 10 ns;

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
begin
	if rising_edge(clk) then
        if rstn = '0' then
            tb_din_a <= (others => '0');
            tb_din_b <= (others => '0');
            tb_din_en <= '0' ;
        else
            if clken = '1' then
                if signed(tb_din_a) = 32767 then
                    tb_din_en <= '0';
                else
                    tb_din_a <= std_logic_vector(signed(tb_din_a) + 1);
                    tb_din_b <= std_logic_vector(signed(tb_din_b) + 1);
                    tb_din_en <= '1';
                end if;
            else
                tb_din_en <= '0';
            end if;
        end if;
	end if;
end process;

DUT: pipelined_multiplier
        port map (
            clk     => clk,
            rstn    => rstn,
            din_a   => tb_din_a,
            din_b   => tb_din_b,
            din_en  => tb_din_en,
            dout_en => tb_dout_en,
            dout    => tb_dout
            ); 
end architecture;

