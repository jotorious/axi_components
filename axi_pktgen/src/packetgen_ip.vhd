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

entity packetgen_ip is
	generic(
		PKTLEN : integer := 32
		);
	port(
        clk	: in std_logic;
		rst	: in std_logic;
		din	: in  std_logic_vector(31 downto 0);
		din_en : in std_logic;
        din_last : in std_logic;
		dout	: out std_logic_vector(31 downto 0);
		dout_en : out std_logic;
        dout_last : out std_logic;
        dout_user : out std_logic_vector(23 downto 0);
        pktlen_reg : in std_logic_vector(31 downto 0);
        sample_count : out std_logic_vector(31 downto 0);
        opacket_count : out std_logic_vector(31 downto 0);
        ipacket_count : out std_logic_vector(31 downto 0);
        tot_sample_count : out std_logic_vector(31 downto 0)

		);
end packetgen_ip;

architecture beh of packetgen_ip is
 
subtype slv32 is STD_LOGIC_VECTOR(31 DOWNTO 0);

signal counter_low : slv32;
signal counter_high : slv32;
signal i_dout : slv32;
signal i_dout_last : std_logic;
signal i_dout_user : std_logic_vector(23 downto 0);

signal tmp_din : std_logic_vector(31 downto 0);
signal tmp_din_en : std_logic;

signal packetlen : integer := PKTLEN;

signal i_outpkt_count : std_logic_vector(31 downto 0);
signal i_inpkt_count : std_logic_vector(31 downto 0);

begin


dec_proc: process(clk)
variable test_cnt : integer;
begin
    if rising_edge(clk) then
        if rst = '0' then
           test_cnt := 0;
           tmp_din <= (others=> '0');
           tmp_din_en <= '0';
        else
            if din_en = '1' then
                test_cnt := test_cnt + 1;
                if test_cnt = 4 then
                    test_cnt := 0;
                    tmp_din <= din;
                    tmp_din_en <= '1';
                else
                    tmp_din <= tmp_din;
                    tmp_din_en <= '0';
                end if;
            else
                tmp_din <= tmp_din;
                tmp_din_en <= '0';
            end if;
        end if;
    end if;
end process;
                



main_proc: process(clk)

variable smp_cnt : integer;
variable v_outpkt_cnt : integer;
variable v_inpkt_cnt : integer;

	begin
	if rising_edge(clk) then
        if rst = '0' then
            counter_low <= (others => '0');
            counter_high <= (others => '0');
            i_outpkt_count <= (others=>'0');
            i_inpkt_count <= (others=>'0');
            i_dout <= (others => '0');
            i_dout_user <= (others => '0');
            i_dout_last <= '0';
            dout_en <= '0';
            smp_cnt := 0;
            v_outpkt_cnt := 0;
            v_inpkt_cnt := 0;
            packetlen <=to_integer(unsigned(pktlen_reg(23 downto 0)));
        else
            if din_en = '1' then
                -- Count the total number of samples through
                if (counter_low = x"FFFFFFFF") then
                    counter_low <= x"00000000";
                    counter_high <= std_logic_vector(unsigned(counter_high) + 1);   
                else
                    counter_low <= std_logic_vector(unsigned(counter_low) + 1);
                end if;
                
                
                
                -- Count the number of samples in this output packet                
                smp_cnt := smp_cnt + 1;

                -- when the number of samples received is the desired pktlen,
                -- pulse the last bit for a beat
                if (smp_cnt = packetlen) then
                    smp_cnt := 0;
                    -- Count the number of output packets 
                    v_outpkt_cnt := v_outpkt_cnt + 1;
                    i_dout_last <= '1';
                else
                    v_outpkt_cnt := v_outpkt_cnt;
                    i_dout_last <= '0';
                end if;
                i_dout_user <= std_logic_vector(to_unsigned(smp_cnt,24));
                i_outpkt_count <= std_logic_vector(to_unsigned(v_outpkt_cnt,32));

                -- Count the number of input packets
                if din_last = '1' then
                    v_inpkt_cnt := v_inpkt_cnt + 1;
                end if;
                i_inpkt_count <= std_logic_vector(to_unsigned(v_inpkt_cnt,32));

                i_dout <= din;
                --i_dout_last <= din_last;
                dout_en <= '1';
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

opacket_count <= i_outpkt_count;
ipacket_count <= i_inpkt_count;

tot_sample_count <= counter_low;
sample_count <= x"00" & i_dout_user(23 downto 0);
  
end architecture;

