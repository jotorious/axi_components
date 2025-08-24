-- ***************************************************************************
-- 01/26/2106
-- Joe McKinney
-- BIT Systems
-- This VHDL code is supposed to create discard samples from output frames of
-- a serially output N-Point IFFT.
-- This design is part of the design for a bank of subband tuners
-- that performs Tune-Filter-Decimate, based on the paper
-- "Turning Overlap-Save into a Multiband Mixing, Downsampling Filter Bank"
--
-- This discard functionality outputs frames of length N-(P-1) samples,
-- created by discarding the first P-1 samples of an N sample long frame
--
-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity discard_samples is
	--generic(
	--	P : integer range 4 to 1024:= 4;   -- P is overlap length (also filter length-1)
	--	N : integer range 16 to 4096:= 4096  -- N is FFT Length
	--	);
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
        dout : out std_logic_vector(31 downto 0);

        N : in std_logic_vector(15 downto 0);
        P : in std_logic_vector(15 downto 0)
		);
end discard_samples;

architecture beh of discard_samples is

type cmplx16 is record
      q : std_logic_vector(15 downto 0);
      i : std_logic_vector(15 downto 0);
end record cmplx16;


signal test_dout, test_din : cmplx16;

attribute mark_debug : string;
attribute keep : string;

signal int_din, int_dout : std_logic_vector(31 downto 0);
signal int_din_user, int_dout_user : std_logic_vector(15 downto 0);
signal int_din_en, int_din_last, int_dout_en, int_dout_last : std_logic;
  
--attribute mark_debug of int_din : signal is "true";
--attribute mark_debug of int_din_en : signal is "true";
--attribute mark_debug of int_din_last : signal is "true";
--attribute mark_debug of int_din_user : signal is "true";

--attribute mark_debug of int_dout : signal is "true";
--attribute mark_debug of int_dout_en : signal is "true";
--attribute mark_debug of int_dout_last : signal is "true";
--attribute mark_debug of int_dout_user : signal is "true";



begin

-- Assign Output signals
dout <= int_dout;
dout_last <= int_dout_last;
dout_en   <= int_dout_en; 
dout_user <= int_dout_user;

-- for internal debug
int_din <= din;
int_din_en <= din_en;
int_din_last <= din_last;
int_din_user <= din_user;

test_din  <= (din(31 downto 16),din(15 downto 0));
test_dout <= (int_dout(31 downto 16),int_dout(15 downto 0));


main_proc: process(clk)
	variable n_count : integer;
	begin
	
	if rising_edge(clk) then
        if rstn = '0' then
    		n_count:= 0;
    		int_dout <= (others => '0');
            int_dout_en <= '0';
        elsif (din_en = '1') then
            
            if n_count < unsigned(P) then
                -- discard P-1 samples out
                int_dout <= (others=> '0');
                int_dout_last <= '0';
                int_dout_user <= (others=> '0');
                int_dout_en <= '0';
            elsif (n_count >= unsigned(P)) then
                -- Write new inputs out
                int_dout <= din;
                int_dout_last <= din_last;
                int_dout_user <= din_user;
                int_dout_en <= '1';
            end if;
            n_count := n_count + 1;
            if n_count = unsigned(N) then
                n_count := 0;
            end if;

        else
            int_dout_en <= '0';
        end if;
	end if;
end process;
  
end architecture;

