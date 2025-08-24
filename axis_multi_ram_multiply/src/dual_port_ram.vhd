library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use IEEE.std_logic_textio.all;

entity dual_port_ram is
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
end dual_port_ram;

architecture behavioral of dual_port_ram is

    type memory_vect_type is array(0 to depth-1) of std_logic_vector(31 downto 0);
	
    -- This function runs at synthesis time
	impure function InitRamFromFile (RamFileName : in string) return memory_vect_type is
		-- This is a dummy to locate where the synthesixer or simulator looks
        file outfile : text open write_mode is "inferred_ROM_synthesis3.txt";

		file  RamFile : text open read_mode is RamFileName;

		variable RamFileLine : line;
		variable RAM : memory_vect_type;
		variable good : boolean;
		variable data_tmp : std_logic_vector(31 downto 0) := (others => '0');   
		begin
            for i in 0 to depth-1 loop
				readline (RamFile, RamFileLine);
				hread(RamFileLine, data_tmp, good); assert good report "text i/o read error" severity error;
				RAM(i) := data_tmp;   
			end loop;
		return RAM;
	end function;


    shared variable RAM : memory_vect_type := InitRamFromFile(data_in_file);
begin

    process(CLKA)
    begin
    if rising_edge(CLKA) then
        if ENA = '1' then
            if WEA = '1' then
             RAM(to_integer(unsigned(ADDRA))) := dina;
            else
             douta <= RAM(to_integer(unsigned(ADDRA)));
            end if;
        end if;
    end if;
    end process;

    process(CLKB)
    begin
    if rising_edge(CLKB) then
        if ENB = '1' then
            if WEB = '1' then
             RAM(to_integer(unsigned(ADDRB))) := dinb;
            else
             doutb <= RAM(to_integer(unsigned(ADDRB)));
            end if;
        end if;
    end if;
    end process;

end behavioral;
