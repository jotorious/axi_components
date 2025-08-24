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

entity fd_gainctrl is
	generic(
		PKTLEN : integer := 32
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
        din_user : in std_logic_vector(23 downto 0);
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(23 downto 0);
        control_reg : in std_logic_vector(31 downto 0);
        status_reg0 : out std_logic_vector(31 downto 0);
        status_reg1 : out std_logic_vector(31 downto 0);
        status_reg2 : out std_logic_vector(31 downto 0)
		);
end fd_gainctrl;

architecture beh of fd_gainctrl is
 
subtype slv32 is STD_LOGIC_VECTOR(31 DOWNTO 0);

signal i_dout : slv32;
signal i_dout_last : std_logic;
signal i_dout_user : std_logic_vector(23 downto 0);
signal direct_control : std_logic_vector(3 downto 0);
signal gain_ctrl : std_logic_vector(1 downto 0);

signal tmp_i, shift_i : std_logic_vector(15 downto 0);
signal tmp_q, shift_q : std_logic_vector(15 downto 0);

signal shift_bits, blk_exp, direct_control5  : std_logic_vector(4 downto 0);


begin


shift_i <= shift_right(signed(tmp_i),to_integer(shift_bits));
shift_q <= shift_right(signed(tmp_q),to_integer(shift_bits));

direct_control <= control_reg(3 downto 0);
direct_control5 <= "0" & direct_control;

gain_ctrl      <= control_reg(5 downto 4);


shift_bits <="00000"         when gainctrl = "00" else
             direct_control when gainctrl = "01" else
             blk_exp        when gainctrl = "10" else
             "00000";
            
          
main_proc: process(clk)
	begin
	if rising_edge(clk) then
        if rst = '0' then
            null;
            blk_exp <= ( others=>'0');
        else
            if din_en = '1' then
                i_dout <= din;
                i_dout_last <= din_last;
                dout_en <= '1';

                tmp_i <= din(15 downto 0);
                tmp_q <= din(31 downto 16);
                blk_exp <= din_user(20 downto 16);

                status_reg0 <= x"00" & "000" & din_user(20 downto 16);

            else
                i_dout <= i_dout;
                i_dout_last <= i_dout_last;
                dout_en <= '0';
            end if;
        end if;
    end if;
end process;

--out ports
dout <= i_dout;
dout_last <= i_dout_last;
dout_user <= i_dout_user;
  
end architecture;

