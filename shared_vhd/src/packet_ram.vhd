-- Simple Dual-Port Block RAM with One Clock
-- Correct Modelization with a Shared Variable
-- File:simple_dual_one_clock.vhd

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity packet_ram is
    generic (
        MDEPTH : integer
    );
    port (
      clk   : in  std_logic;
      ena   : in  std_logic;
      enb   : in  std_logic;
      wea   : in  std_logic;
      wr_addr : in  std_logic_vector(15 downto 0);
      rd_addr : in  std_logic_vector(15 downto 0);
      din   : in  std_logic_vector(31 downto 0);
      dout   : out std_logic_vector(31 downto 0)
    );
end packet_ram;

architecture syn of packet_ram is
 type ram_type is array (MDEPTH -1 downto 0) of std_logic_vector(31 downto 0);
 --shared variable RAM : ram_type;
 shared variable RAM : ram_type := (others => (others =>'1'));
begin
 process(clk)
 begin
  if rising_edge(clk) then
   if ena = '1' then
    if wea = '1' then
     RAM(conv_integer(wr_addr)) := din;
    end if;
   end if;
  end if;
 end process;

 process(clk)
 begin
  if rising_edge(clk) then
   if enb = '1' then
    dout <= RAM(conv_integer(rd_addr));
   end if;
  end if;
 end process;

end syn;
