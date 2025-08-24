-- ***************************************************************************
-- 
-- Joe McKinney
-- BIT Systems
-- 
-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity pipelined_multiplier is
	port(
		clk : IN STD_LOGIC;
        rstn : IN STD_LOGIC;
        din_a : in std_logic_vector(15 downto 0);
        din_b : in std_logic_vector(15 downto 0);
        
        din_en: in std_logic;
        dout_en : out std_logic;
        dout : out std_logic_vector(31 downto 0)

        );
end pipelined_multiplier;

architecture beh of pipelined_multiplier is


signal pl_din_a, pl_din_b : std_logic_vector(15 downto 0);
signal int_dout : std_logic_vector(31 downto 0);
signal pl_en : std_logic_vector (2 downto 0) ;

begin



main_proc: process(clk)
begin
	if rising_edge(clk) then
        if rstn = '0' then
    		int_dout <= (others => '0');
    		pl_en <= (others => '0');
        else
            pl_din_a <= din_a;
            pl_din_b <= din_b;
            pl_en(0) <= din_en;
            pl_en(2 downto 1) <= pl_en(1 downto 0);
            int_dout <= std_logic_vector(signed(pl_din_a) * signed(pl_din_b));
            dout <= int_dout;
        end if;
	end if;
end process;

dout_en <= pl_en(2);
  
end architecture;

