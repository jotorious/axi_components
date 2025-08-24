----------------------------------------------------------------------------------
-- Company: BIT Systems
-- Engineer: Joseph McKinney
-- 
-- Design Name: 
-- Module Name: inferred_rom
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
-- This VHDL code is intended to infer a ROM with depth "depth" and the contents of the 
-- data_in_file from BRAM resources
-- This code is adapted from example code on the internet
-- for the purposes of providing a the Frequency Domain Response / Representation of a
-- Low Pass Filter, Each 32-bit row contains the Real and imaginary parts of the FFT of
-- the impulse response / time-domain coefficients of the filter
-- The filter_coefs.coe file was generated using a custom python script "filt_gen.py"
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.numeric_std.all;
USE ieee.math_real.all;
USE ieee.std_logic_1164.all;
--USE ieee.std_logic_unsigned.all;
use std.textio.all;
use IEEE.std_logic_textio.all;


ENTITY inferred_rom IS
	GENERIC (
        depth : integer := 2048;
		data_in_file: string    := "filter_coefs.data" 
	);
	PORT (
		clka : IN STD_LOGIC;
		ena : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
	
END inferred_rom;

ARCHITECTURE RTL OF inferred_rom IS

	type    memory_vect_type     is array(0 to depth-1) of std_logic_vector(31 downto 0);
	
	impure function InitRamFromFile (RamFileName : in string) return memory_vect_type is
		-- This is a dummy to locate where the synthesixer or simulator looks
        -- otherwise it's like looking for a Needle in a Haystack
        
        file outfile : text open write_mode is "inferred_ROM_synthesis2.txt"; 
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

    -- This file read happens at synthesis time
	signal memory : memory_vect_type := InitRamFromFile(data_in_file);
	-- this tells the synthesizer that it's doesn't need to keep the named object through synthesis (I think)
	ATTRIBUTE keep : string;
	ATTRIBUTE keep of memory : signal is "false";
    -- this tells the synthesizer to try to identify a ROM from my HDL
	ATTRIBUTE rom_extract : string;
	ATTRIBUTE rom_extract of memory : signal is "yes";
    -- this tells the synthesizer to use BRAM
	ATTRIBUTE rom_style : string;
	ATTRIBUTE rom_style of memory : signal is "block";

   begin
		
	process (clka) is
	begin
		if rising_edge(clka) then
			if (ena ='1') then
				douta <= memory(to_integer(unsigned(addra)));
			end if;
		end if;
	end process;	
END RTL;
