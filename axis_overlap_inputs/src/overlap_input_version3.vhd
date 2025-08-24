-- ***************************************************************************
-- 01/26/2106
-- Joe McKinney
-- BIT Systems
-- This VHDL code is supposed to create overlapped input frames for
-- a serially input N-Point FFT.
-- This design is part of the design for a bank of subband tuners
-- that performs Tune-Filter-Decimate, based on the paper
-- "Turning Overlap-Save into a Multiband Mixing, Downsampling Filter Bank"
--
-- The overlap save functionality outputs N-sample frames with the first
-- P-1 Samples copied from the end if the previous frame
-- Thus this block takes in N-(P-1) samples and outputs N samples
-- This imposes a constraint that the clock runs at least at the output rate
-- This block designed to receive data from the read interface of a Fifo with the appropriate clk
-- This block does not do any clock crossing
--
-- The major functionality of the block is a Modulo-N counter (+1)
-- that 1) on the first P-1 clocks writes to the output the samples from the previous frame,
-- 2) on the next N - 2(P-2)(?) clocks writes to the output the new incoming samples
-- and 3) on the last P-1 clocks writes to the output the new incoming sample and stores
-- these samples into a FIFO for retrival by at the next frame   
-- ***************************************************************************

-- Library *******************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

-- Entity Declaration ********************************************************

entity overlap_input_version3 is
	generic(
		RAMDEPTH : integer range 8 to 1024:= 1024
		);
	port(
		
        clk	: in std_logic;
		rst	: in std_logic;

        run : in std_logic;        
        n_minus_p : in std_logic_vector(15 downto 0); --768
        n : in std_logic_vector (15 downto 0); --1024
        p : in std_logic_vector (15 downto 0);        

        din	: in  std_logic_vector(31 downto 0);
        din_vld : in std_logic;
        din_rdy : out std_logic;
        din_idx : in std_logic_vector(15 downto 0);
		
        dout	: out std_logic_vector(31 downto 0);
        dout_vld : out std_logic;
        dout_rdy : in std_logic;
        dout_idx : out std_logic_vector(15 downto 0);
        dout_last : out std_logic;

        samples_in : out std_logic_vector(31 downto 0);
        samples_out : out std_logic_vector(31 downto 0)

		);
end overlap_input_version3;

architecture beh of overlap_input_version3 is


component packet_ram is
    generic (
        MDEPTH : integer
    );
    port(
      clk   : in  std_logic;
      ena   : in  std_logic;
      enb   : in  std_logic;
      wea   : in  std_logic;
      wr_addr : in  std_logic_vector(15 downto 0);
      rd_addr : in  std_logic_vector(15 downto 0);
      din   : in  std_logic_vector(31 downto 0);
      dout   : out std_logic_vector(31 downto 0)
    );
end component;

attribute mark_debug : string;
attribute keep : string;
  
--attribute mark_debug of pktbuf_dout : signal is "true";


-- Signals to RAM
signal wr_en, rd_en : std_logic;
signal waddr, raddr : std_logic_vector(15 downto 0);
signal ram_din,ram_dout : std_logic_vector(31 downto 0);

-- Just process signals
signal p_samplecnt, p_waddr, p_raddr: std_logic_vector(15 downto 0);

--attribute mark_debug of p_samplecnt : signal is "true";
--attribute mark_debug of waddr : signal is "true";
--attribute mark_debug of raddr : signal is "true";

--attribute mark_debug of p_waddr : signal is "true";
--attribute mark_debug of p_raddr : signal is "true";

--attribute mark_debug of ram_din : signal is "true";
--attribute mark_debug of ram_dout : signal is "true";

signal rd_out_idx : std_logic_vector(15 downto 0);

type data_dly_line is array (3 downto 0) of std_logic_vector(31 downto 0);
signal din_dly: data_dly_line;
signal din_en_dly : std_logic_vector (3 downto 0);

type addr_dly_line is array (3 downto 0) of std_logic_vector(15 downto 0);
signal p_samplecnt_dly : addr_dly_line;
signal waddr_dly, raddr_dly : addr_dly_line;


--attribute mark_debug of waddr_dly : signal is "true";
--attribute mark_debug of raddr_dly : signal is "true";

signal wp : std_logic_vector(0 to 1023) := (others=>'0');


signal n_minus_one : std_logic_vector(15 downto 0);
signal p_minus_one : std_logic_vector(15 downto 0);
signal n_minus_p_minus_one : std_logic_vector(15 downto 0);

attribute mark_debug of n_minus_one : signal is "true";
attribute mark_debug of p_minus_one : signal is "true";
attribute mark_debug of n_minus_p_minus_one : signal is "true";


signal dv_on_ram : std_logic;
signal dout_from_ram_vld, dout_from_reg_vld : std_logic;

signal test_n, test_p, test_nmp : std_logic_vector(15 downto 0);

attribute mark_debug of test_n : signal is "true";
attribute mark_debug of test_p : signal is "true";
attribute mark_debug of test_nmp : signal is "true";


signal stuffing : std_logic;


signal blah : std_logic;

signal testme : std_logic_vector(3 downto 0);
signal bad_shit : std_logic;

signal dout_from_ram,dout_from_reg : std_logic_vector(31 downto 0);

signal i_samples_in, i_samples_out : std_logic_vector(31 downto 0);

signal test_din_vld, test_dout_rdy : std_logic;

attribute mark_debug of test_din_vld : signal is "true";
attribute mark_debug of test_dout_rdy : signal is "true";

attribute mark_debug of rd_en : signal is "true";
attribute mark_debug of testme : signal is "true";

--attribute mark_debug of rd_en : signal is "true";

--attribute mark_debug of bad_shit : signal is "true";

signal test_oi_resetn, test_oi_run : std_logic;
signal reset_issued : std_logic := '0';
attribute mark_debug of reset_issued : signal is "true";

attribute mark_debug of test_oi_resetn : signal is "true";
attribute mark_debug of test_oi_run : signal is "true";



begin

test_din_vld <= din_vld;
test_dout_rdy <= dout_rdy;

test_oi_resetn <= rst;
test_oi_run    <= run;

test_n <= n;
test_p <= p;
test_nmp <= n_minus_p;


ram_inst : packet_ram
    generic map(
        MDEPTH => RAMDEPTH
    )
    port map (
        clk => clk,
        ena => '1',
        enb => rd_en,
        wea  => wr_en,
        wr_addr  => waddr,
        rd_addr  => raddr,
        din    => ram_din,
        dout    => ram_dout
    );

din_rdy <= '1' when din_vld = '1' and dout_rdy = '1' and stuffing = '0' else '0';


dout_vld <= dout_from_ram_vld or dout_from_reg_vld;
bad_shit <= dout_from_ram_vld and dout_from_reg_vld;
dout <= dout_from_ram when dout_from_ram_vld = '1' else
        dout_from_reg when dout_from_reg_vld = '1' else
        (others=>'0');


rw_proc: process(clk)
	begin
	if rising_edge(clk) then
        if rst = '0' then
            testme <= "1111";
            wr_en <= '0';
            rd_en <= '0';

            p_waddr <= (others=>'0');
            p_raddr <= (others=>'0');
            p_samplecnt <= x"0000";

            -- These signals need to not be reset by DMA Controller
            n_minus_one <= std_logic_vector(unsigned(n) - 1); -- 63
            n_minus_p_minus_one <= std_logic_vector(unsigned(n_minus_p) - 1); --47
            p_minus_one <= std_logic_vector(unsigned(p) - 1);  -- 15

            din_en_dly <= (others =>'0');
            din_dly <= ( others=> (others=>'0') );

            dout_from_reg_vld <= '0';
            dout_from_reg <= x"11111111";
            dout_from_ram_vld <= '0';
            dout_from_ram <= x"22222222";

            ram_din <= x"33333333";

            i_samples_in <= (others=>'0');
            i_samples_out <= (others=>'0');
            reset_issued <= '1';
        
        elsif (reset_issued = '1') and (run = '1') then
            p_samplecnt_dly(0) <= p_samplecnt;
            p_samplecnt_dly(3 downto 1) <= p_samplecnt_dly(2 downto 0);
            waddr_dly(0) <= p_waddr;

            din_dly(3 downto 1) <= din_dly(2 downto 0);
            din_en_dly (3 downto 1) <= din_en_dly(2 downto 0);

            --------------------
            -- RAM Read
            --------------------
            
            if (rd_en = '1') then
                -- Clock 1
                dv_on_ram <= '1';
                -----dout <= ram_dout;
            else
                dv_on_ram <= '0';
            end if;
            if dv_on_ram = '1' then
                -- Clock 2
                dout_from_ram <= ram_dout;
                dout_from_ram_vld <= '1';  --high on clock 3
                i_samples_out <= std_logic_vector(unsigned(i_samples_out) + 1);

            else
                dout_from_ram_vld <= '0';
            end if;

            if (din_en_dly(1) = '1') then
                dout_from_reg <= din_dly(1);
                dout_from_reg_vld <= '1';
                i_samples_out <= std_logic_vector(unsigned(i_samples_out) + 1);
            else
                dout_from_reg_vld <= '0';
            end if;


            if (unsigned(p_samplecnt) < unsigned(p_minus_one)) then   
               ----------------------
               --- Read ram  -> 0 to 14
               ----------------------
               -- Clock 0
                din_en_dly (0) <= '0';
                stuffing <= '1';
                if dout_rdy = '1' then
                    rd_en <= '1';
                    raddr_dly(0) <= p_raddr;
                    p_samplecnt <= std_logic_vector(unsigned(p_samplecnt) + 1 );
                    p_raddr <= std_logic_vector(unsigned(p_raddr) + 1 );
                    testme <= "0001";
                else
                    rd_en <= '0';
                    testme <= "0010";           
                end if;
            ------------------------
            -- Last read ram -> 15
            ------------------------
            elsif (unsigned(p_samplecnt) = unsigned(p_minus_one)) then
                if dout_rdy = '1' then
                    stuffing <= '0';
                    rd_en <= '1';
                    raddr_dly(0) <= p_raddr;
                    
                    p_samplecnt <= std_logic_vector(unsigned(p_samplecnt) + 1 );
                    p_raddr <= (others=>'0');
                    testme <= "0011";
                else
                    rd_en <= '0';
                    testme <= "0100";           
                end if;


            ------------------------
            -- Passthrough data -> 16 to 47
            ------------------------

            elsif ((unsigned(p_samplecnt) > unsigned(p_minus_one)) and (unsigned(p_samplecnt) <= unsigned(n_minus_p_minus_one))) then
                rd_en <= '0';
                -- PASSTHROUGH DATA
                if ((din_vld = '1')) then
                    if dout_rdy = '1' then
                        i_samples_in <= std_logic_vector(unsigned(i_samples_in) + 1);

                        din_dly(0) <= din;
                        din_en_dly (0) <= '1';
                        
                        p_samplecnt <= std_logic_vector(unsigned(p_samplecnt) + 1 );
                        testme <= "0101";
                    else
                        --dout_vld <= '0';
                        din_en_dly (0) <= '0';
                    end if;
                else
                    din_en_dly (0) <= '0';
                    testme <= "0110";            
                end if;

            ------------------------
            -- Passthrough data and write RAM -> 48 to 62
            ------------------------
            elsif ((unsigned(p_samplecnt) > unsigned(n_minus_p_minus_one)) and(unsigned(p_samplecnt) < unsigned(n_minus_one))) then
                rd_en <= '0';
                -- PASSTHROUGH AND WRITE TO RAM
                if ((din_vld = '1')) then
                    if dout_rdy = '1' then
                        i_samples_in <= std_logic_vector(unsigned(i_samples_in) + 1);
                        -- Write new inputs out
                        -- and into fifo
                        din_dly(0) <= din;
                        din_en_dly (0) <= '1';

                        ram_din <= din;
                        wr_en <= '1';
                        p_waddr <= std_logic_vector(unsigned(p_waddr) + 1 );
                        waddr_dly(0) <= p_waddr;
                        p_samplecnt <= std_logic_vector(unsigned(p_samplecnt) + 1 );
                        testme <= "0111";
                    else
                        din_en_dly (0) <= '0';
                        testme <= "1000";
                        wr_en <= '0';           
                    end if;
                else
                    din_en_dly (0) <= '0';
                    testme <= "1001";
                    wr_en <= '0';
                end if;
            ------------------------
            -- Last passthrough data and write ram->  63
            ------------------------
            elsif (unsigned(p_samplecnt) = unsigned(n_minus_one)) then
                rd_en <= '0';
                -- PASSTHROUGH AND WRITE TO RAM
                if ((din_vld = '1')) then
                    stuffing <= '1';
                    if dout_rdy = '1' then
                        i_samples_in <= std_logic_vector(unsigned(i_samples_in) + 1);
                        -- Write new inputs out
                        -- and into fifo
                        din_dly(0) <= din;
                        din_en_dly (0) <= '1';

                        ram_din <= din;
                        wr_en <= '1';
                        p_waddr <= (others=>'0');
                        waddr_dly(0) <= p_waddr;
                        p_samplecnt <= (others=>'0');
                        testme <= "1010";
                    else
                        din_en_dly (0) <= '0';
                        wr_en <= '0';
                        testme <= "1011";            
                    end if;
                else
                    din_en_dly (0) <= '0';
                    wr_en <= '0';
                    testme <= "1100";
                end if;
            end if; --p_sample_cnt
        end if; -- if-rst-else -endif
    end if; -- if rising_edge(clk) end if
end process;		

dout_idx <= p_samplecnt_dly(2);
dout_last <= '1' when (unsigned(p_samplecnt_dly(2)) = unsigned(n_minus_one)) else '0' ;
raddr <= raddr_dly(0);
waddr <= waddr_dly(0);

samples_in <= i_samples_in;
samples_out <= i_samples_out;
  
end architecture;

