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

entity mag_squared is
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
end mag_squared;

architecture beh of mag_squared is

type cmplx16 is record
      q : std_logic_vector(15 downto 0);
      i : std_logic_vector(15 downto 0);
end record cmplx16;

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




signal test_dout, test_din : cmplx16;

attribute mark_debug : string;
attribute keep : string;


signal din_i, din_q : std_logic_vector(15 downto 0);
signal i_squ, q_squ : std_logic_vector(31 downto 0);

signal i_squ_short, q_squ_short : std_logic_vector(15 downto 0);
signal int_mag_squ : std_logic_vector(16 downto 0);


signal i_squ_en, q_squ_en, both_squ_en, int_mag_squ_en, int_dout_last : std_logic;

signal pl_last : std_logic_vector (3 downto 0) ;

type user_arr is array (30 downto 0) of std_logic_vector(15 downto 0);
signal pl_user : user_arr;


  
signal logic_error : std_logic;

-- bit growth
-- x.xxx * x.xxx = xx.xxxxxx
-- so throw away MSB, under the assumption that the set of values
-- represent [-1,1) and that -1*-1 = 0x8000 * 0x8000 will not occur
-- If someone else is reading this; -1 * -1 = 1 but 1 is outside [-1,1)
-- the result of 0x8000 * 0x8000 =>  0x4000 0000, which if interpreted as xx.xxxx ~ 01.0000 is 1
-- This is the only set of operands and result that overflows a x.xxxx fixed point.
-- The overlfow condition is that the 2 MSBs are different.

constant bg : integer := 1;

begin

din_i <= din(15 downto 0);
din_q <= din(31 downto 16);

i_squared_inst: pipelined_multiplier
        port map (
            clk     => clk,
            rstn    => rstn,
            din_a   => din_i,
            din_b   => din_i,
            din_en  => din_en,
            dout_en => i_squ_en,
            dout    => i_squ
            ); 

q_squared_inst : pipelined_multiplier
        port map (
            clk     => clk,
            rstn    => rstn,
            din_a   => din_q,
            din_b   => din_q,
            din_en  => din_en,
            dout_en => q_squ_en,
            dout    => q_squ
            );

logic_error <= i_squ_en xor q_squ_en;
--31 downto 16
--i_squ'left downto i_squ'left-i_squ_short'left
i_squ_short <= i_squ(q_squ'left -bg downto q_squ'left-q_squ_short'left - bg);

q_squ_short <= q_squ(q_squ'left -bg downto q_squ'left-q_squ_short'left - bg);

adder_proc: process(clk)
	variable n_count : integer;
	begin
	
	if rising_edge(clk) then
        if rstn = '0' then
    		pl_last <= (others => '0');
            pl_user <= (others => (others=>'0') );
        else
            if (i_squ_en = '1') then
                int_mag_squ_en <= '1';
                int_mag_squ <= std_logic_vector(resize(signed(i_squ_short),int_mag_squ'length) + resize(signed(q_squ_short),int_mag_squ'length) );
            else
                int_mag_squ_en <= '0';
            end if;
            -- Carry aux signals through. This ASSUMES the 3 clocks from the mult and this single clock for the adder.
            -- If things get stupid, one might need to carry the aux signals down into the pipelined_multiplier and through
            -- this piece of logic
            pl_last(0) <= din_last;
            pl_last(3 downto 1) <= pl_last(2 downto 0);

            pl_user(0) <= din_user;
            pl_user(3 downto 1) <= pl_user(2 downto 0);


        end if;
	end if;
end process;

-- Assign Output signals
dout(31 downto 15) <= int_mag_squ;
dout(14 downto 0) <= (others=>'0');
dout_en   <= int_mag_squ_en;

dout_last <= pl_last(3);
dout_user <= pl_user(3);



  
end architecture;

