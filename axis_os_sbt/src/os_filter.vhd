----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/12/2018 12:02:15 PM
-- Design Name: 
-- Module Name: os_sbt_tb - Testbed
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
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity os_filter is
    generic (
        Nfft : integer := 256;
        P    : integer := 64;
        filter_file: string    := "filter_coefs.data"
    );
    port (
        aclk : IN STD_LOGIC;
        aclken : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        
        s_axis_data_tvalid : in std_logic;
        s_axis_data_tready : out std_logic;
        s_axis_data_tdata : in std_logic_vector(31 downto 0);
        
        m_axis_data_tvalid : out std_logic;
        m_axis_data_tready : in std_logic;
        m_axis_data_tdata : out std_logic_vector(31 downto 0)
    );
end os_filter;

architecture structural of os_filter is

--type axi_stream is record
--    tdata : std_logic_vector;
--    tuser : std_logic_vector;
--    tvalid : std_logic;
--    tready : std_logic;
--    tlast  : std_logic;
--end record axi_stream;

type axi_stream32 is record
    tdata : std_logic_vector(31 downto 0);
    tuser : std_logic_vector(23 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream32;

constant axis32_init : axi_stream32 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');

type axi_stream24 is record
    tdata : std_logic_vector(23 downto 0);
    tuser : std_logic_vector(15 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
end record axi_stream24;

constant axis24_init : axi_stream24 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');
                                              
type axi_stream16 is record
  tdata : std_logic_vector(15 downto 0);
  tuser : std_logic_vector(15 downto 0);
  tvalid : std_logic;
  tready : std_logic;
  tlast  : std_logic;
end record axi_stream16;
  
constant axis16_init : axi_stream16 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');
                                        
type axi_stream8 is record
  tdata : std_logic_vector(7 downto 0);
  tuser : std_logic_vector(7 downto 0);
  tvalid : std_logic;
  tready : std_logic;
  tlast  : std_logic;
end record axi_stream8;
  
constant axis8_init : axi_stream8 := (tdata => (others=> '0'),
                                        tuser => (others=> '0'),
                                        tvalid=> '0',
                                        tready => '0',
                                        tlast => '0');


component overlap_inputs_axis
	generic (
        P : integer range 8 to 1024:= 1024;   -- P is overlap length (also filter length)
        N : integer range 16 to 4096:= 4096;  -- N is FFT Length-- User parameters ends
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_AXIS_START_COUNT	: integer	:= 32;
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
	);
	port (
		-- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_aclk	: in std_logic;
		m_axis_aresetn	: in std_logic;
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;
		s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		s_axis_tstrb	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic
	);
end component;



COMPONENT xfft_0
  PORT (
    aclk : IN STD_LOGIC;
  aclken : IN STD_LOGIC;
  aresetn : IN STD_LOGIC;
  s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
  s_axis_config_tvalid : IN STD_LOGIC;
  s_axis_config_tready : OUT STD_LOGIC;
  s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
  s_axis_data_tvalid : IN STD_LOGIC;
  s_axis_data_tready : OUT STD_LOGIC;
  s_axis_data_tlast : IN STD_LOGIC;
  m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
  m_axis_data_tuser : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
  m_axis_data_tvalid : OUT STD_LOGIC;
  m_axis_data_tready : IN STD_LOGIC;
  m_axis_data_tlast : OUT STD_LOGIC;
  m_axis_status_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
  m_axis_status_tvalid : OUT STD_LOGIC;
  m_axis_status_tready : IN STD_LOGIC;
  event_frame_started : OUT STD_LOGIC;
  event_tlast_unexpected : OUT STD_LOGIC;
  event_tlast_missing : OUT STD_LOGIC;
  event_status_channel_halt : OUT STD_LOGIC;
  event_data_in_channel_halt : OUT STD_LOGIC;
  event_data_out_channel_halt : OUT STD_LOGIC
  );
END COMPONENT;

component cmpy_0
  Port ( 
    aclk : in STD_LOGIC;
    aresetn : in STD_LOGIC;
    s_axis_a_tvalid : in STD_LOGIC;
    s_axis_a_tuser : in STD_LOGIC_VECTOR ( 23 downto 0 );
    s_axis_a_tlast : in STD_LOGIC;
    s_axis_a_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_b_tvalid : in STD_LOGIC;
    s_axis_b_tlast : in STD_LOGIC;
    s_axis_b_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    m_axis_dout_tvalid : out STD_LOGIC;
    m_axis_dout_tuser : out STD_LOGIC_VECTOR ( 23 downto 0 );
    m_axis_dout_tlast : out STD_LOGIC;
    m_axis_dout_tdata : out STD_LOGIC_VECTOR ( 63 downto 0 )
  ); 
END COMPONENT;

component inferred_rom
    GENERIC (
        depth : integer;
        data_in_file: string 
    );
    PORT (
        clka : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        addra : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
end component;

 COMPONENT axis_data_fifo_32_x16
   PORT (
     s_axis_aresetn : IN STD_LOGIC;
     s_axis_aclk : IN STD_LOGIC;
     s_axis_tvalid : IN STD_LOGIC;
     s_axis_tready : OUT STD_LOGIC;
     s_axis_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
     s_axis_tuser : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
     s_axis_tlast : IN STD_LOGIC;
     m_axis_tvalid : OUT STD_LOGIC;
     m_axis_tready : IN STD_LOGIC;
     m_axis_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     M_axis_tuser : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
     m_axis_tlast : OUT STD_LOGIC;
     axis_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     axis_wr_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
     axis_rd_data_count : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
   );
 END COMPONENT;
 
component discard_samples_axis
     generic (
         Nfft : integer;
         P    : integer
     );
     port (
         aclk : IN STD_LOGIC;
         aclken : IN STD_LOGIC;
         aresetn : IN STD_LOGIC;
         
         s_axis_data_tvalid : in std_logic;
         s_axis_data_tready : out std_logic;
         s_axis_data_tdata : in std_logic_vector(31 downto 0);
         
         m_axis_data_tvalid : out std_logic;
         m_axis_data_tready : in std_logic;
         m_axis_data_tlast  : out std_logic;
         m_axis_data_tdata : out std_logic_vector(31 downto 0)
     );
 end component;



function f_log2 (x: positive) return integer is
  variable i : integer;
begin
  i := 0;
  while(2**i < x) and (i < 31) loop
    i := i + 1;
  end loop;
  return i;
end function;


  --signal oi : axi_stream(tdata(31 downto 0), tuser(7 downto 0));
  --signal fft_dout : axi_stream(tdata(31 downto 0),tuser(15 downto 0));
  --signal fft_cnfg : axi_stream(tdata(23 downto 0), tuser (7 downto 0));
  
  signal oi_m : axi_stream32 := axis32_init;
  signal fft_dout : axi_stream32 := axis32_init;
  signal fft_cnfg : axi_stream16 := axis16_init;
  signal fft_dout_dly1 : axi_stream32 := axis32_init;
  
  signal fft_status : axi_stream8 := axis8_init;
  
  signal mult_dout : axi_stream32 := axis32_init;
  signal mult_dout_dlong : std_logic_vector(63 downto 0);
  
  signal fifo_dout : axi_stream32 := axis32_init;
  
  signal dummy : std_logic;
  
  signal ifft_dout : axi_stream32 := axis32_init;
  signal ifft_cnfg : axi_stream16 := axis16_init;
  
  signal ifft_status : axi_stream8 := axis8_init;
  
  signal sbt_dout : axi_stream32 := axis32_init;
  
  
  -- Event signals
  signal fft_event_frame_started         : std_logic := '0';
  signal fft_event_tlast_unexpected      : std_logic := '0';
  signal fft_event_tlast_missing         : std_logic := '0';
  signal fft_event_data_in_channel_halt  : std_logic := '0';
  signal fft_event_data_out_channel_halt  : std_logic := '0';
  signal fft_event_status_channel_halt  : std_logic := '0';
  -- Event signals
  signal ifft_event_frame_started         : std_logic := '0';
  signal ifft_event_tlast_unexpected      : std_logic := '0';
  signal ifft_event_tlast_missing         : std_logic := '0';
  signal ifft_event_data_in_channel_halt  : std_logic := '0';
  signal ifft_event_data_out_channel_halt  : std_logic := '0';
  signal ifft_event_status_channel_halt  : std_logic := '0';
  
  --constant n_fft: integer := 32;
  --signal log2_n : std_logic_vector(7 downto 0) := x"05";
  signal log2_n : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned( f_log2(Nfft) , 8) ); 
  
  signal fwd_inv : std_logic := '1';
  signal fft_sc_sch :std_logic_vector(11 downto 0);
  signal fft_sc_sch_ext : std_logic_vector(14 downto 0);
  
  signal ifft_sc_sch :std_logic_vector(11 downto 0);
  signal ifft_sc_sch_ext : std_logic_vector(14 downto 0);
  
  signal fft_config_done :std_logic := '0';
  signal fft_config_done_dly1 :std_logic := '0';
  signal fft_config_done_dly2 :std_logic := '0';
  
  signal ifft_config_done :std_logic := '0';
  signal ifft_config_done_dly1 :std_logic := '0';
  signal ifft_config_done_dly2 :std_logic := '0';

  signal fft_xk_index : std_logic_vector(11 downto 0);
  signal fft_blk_exp: std_logic_vector(4 downto 0);
 
  signal ifft_xk_index : std_logic_vector(11 downto 0);
  signal ifft_blk_exp: std_logic_vector(4 downto 0);
  
  signal fft_once_per_frame : std_logic;
  signal ifft_once_per_frame : std_logic;
  
  type blk_exp_ram_t is array (0 to 7) of std_logic_vector(4 downto 0);
  signal blk_exp_ram : blk_exp_ram_t;
  
  signal blk_exp_in: std_logic_vector(4 downto 0);
  
  signal fft_frm_cnter : std_logic_vector(7 downto 0);
  signal ifft_frm_cnter : std_logic_vector(7 downto 0);

  
  signal oi_s_tready :std_logic := '0';
  signal oi_s_tvalid :std_logic := '0';
  
  signal oi_m_tfirst : std_logic := '0';
  signal aresetn_oi : std_logic := '0';
  
  signal rom_addr : std_logic_vector(31 downto 0) := (others=>'0');
  signal rom_data : std_logic_vector(31 downto 0) := (others=>'0');
  signal rom_last_addr : std_logic := '0';
  signal rom_last_data : std_logic := '0';
  
  signal axis_data_count : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal axis_wr_data_count : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal axis_rd_data_count : STD_LOGIC_VECTOR(31 DOWNTO 0);
  
  signal internal_m_axis_data_tlast : std_logic;
  
  type cmplx16 is record
      re : std_logic_vector(15 downto 0);
      im : std_logic_vector(15 downto 0);
  end record cmplx16;
  
  signal test_oim,test_fftout, test_rom, test_multout, test_ifftout, test_sbtout : cmplx16;

  constant cmpy_bg : integer := 1;

  signal cmpy_shift : integer range 0 to Nfft;
  
  
begin
fft_sc_sch <= x"AAA";
fft_sc_sch_ext <= "000" & fft_sc_sch;
-- scaled option: fft_cnfg.tdata <= fft_sc_sch_ext & fwd_inv & log2_n;
-- w/ block fp, we don't provide scaling schedule, and tdata is 9 bits padded to 16
fft_cnfg.tdata <= x"0" & "000" & fwd_inv & log2_n;
fft_cnfg.tvalid <= '1';

ifft_sc_sch <= x"000";
ifft_sc_sch_ext <= "000" & ifft_sc_sch;
-- scaled option: ifft_cnfg.tdata <= ifft_sc_sch_ext & (not fwd_inv) & log2_n;
ifft_cnfg.tdata <= x"0" & "000"  & (not fwd_inv) & log2_n;
 
ifft_cnfg.tvalid <= '1';

---------------------------------------------------------
-- FFT Core Configuration logic
---------------------------------------------------------

cfng_fft_proc:process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            aresetn_oi <= '0';
            fft_config_done <= '0';
            ifft_config_done <= '0';
        else
            fft_config_done_dly1 <= fft_config_done;
            fft_config_done_dly2 <= fft_config_done_dly1;
            
            ifft_config_done_dly1 <= ifft_config_done;
            ifft_config_done_dly2 <= ifft_config_done_dly1;
            
            if fft_config_done = '0' then
                --wait for tready
                --s_axis_data_tready <= '0';
                if fft_cnfg.tready = '1' then
                    fft_config_done <= '1';
                end if;
            end if;
            
            if ifft_config_done = '0' then
                --wait for tready
                --s_axis_data_tready <= '0';
                if ifft_cnfg.tready = '1' then
                    ifft_config_done <= '1';
                end if;
            end if;
            
            
            if ((fft_config_done_dly2 = '1') AND (ifft_config_done_dly2 = '1')) then
                aresetn_oi <= '1';
            end if;
        end if;
    end if;
end process;

-- Switch upside ready on FFT is configured -- This is just an AND gate idiot.
s_axis_data_tready <= '1' when oi_s_tready = '1' and fft_config_done_dly2 = '1' else '0';
--
oi_s_tvalid <= s_axis_data_tvalid when fft_config_done_dly2 = '1' else '0';


---------------------------------------------------------
-- Overlap Inputs Logic
-- This Needs to be better wrung out
--
--
-- This data needs to be spaced on the input so that the 
-- output rate is supported. For input at X MSamp/sec,
-- the output rate is X*(N/(N-P+1))
---------------------------------------------------------


  oi_axis_inst : overlap_inputs_axis
    GENERIC MAP (
      P => P,
      N => Nfft,
      C_M_AXIS_TDATA_WIDTH => 32,
      C_M_AXIS_START_COUNT => 32,
      C_S_AXIS_TDATA_WIDTH => 32
    )
    PORT MAP (
        m_axis_aclk => aclk,
        m_axis_aresetn => aresetn_oi,
        m_axis_tvalid => oi_m.tvalid,
        m_axis_tdata => oi_m.tdata,
        m_axis_tstrb => open,
        m_axis_tlast => oi_m.tlast,
        m_axis_tready => oi_m.tready,
          
        s_axis_aclk => aclk,
        s_axis_aresetn => aresetn_oi,
        s_axis_tready => oi_s_tready,
        s_axis_tdata => s_axis_data_tdata,
        s_axis_tstrb => (others=> '0'),
        s_axis_tlast => '0',
        s_axis_tvalid => oi_s_tvalid
    );


---------------------------------------------------------
-- Forward FFT Core
-- tlast is weakly used to ensure proper framing
-- But as long as the event signals look right...
---------------------------------------------------------


test_oim.re<= oi_m.tdata(15 downto 0);
test_oim.im <= oi_m.tdata(31 downto 16);
  
fft_inst : xfft_0
    PORT MAP (
      aclk => aclk,
      aclken => '1',
      aresetn => aresetn,
      s_axis_config_tdata => fft_cnfg.tdata,
      s_axis_config_tvalid =>fft_cnfg.tvalid,
      s_axis_config_tready => fft_cnfg.tready,
      
      s_axis_data_tdata     => oi_m.tdata,
      s_axis_data_tvalid    => oi_m.tvalid,
      s_axis_data_tready    => oi_m.tready,
      s_axis_data_tlast     => oi_m.tlast,
      
      m_axis_data_tdata     => fft_dout.tdata,
      m_axis_data_tuser     => fft_dout.tuser,
      m_axis_data_tvalid    => fft_dout.tvalid,
      m_axis_data_tlast     => fft_dout.tlast,
      m_axis_data_tready     => fft_dout.tready,
      
      m_axis_status_tdata     => fft_status.tdata,
      m_axis_status_tvalid    => fft_status.tvalid,
      m_axis_status_tready     => fft_status.tready,
      
      event_frame_started           => fft_event_frame_started,
      event_tlast_unexpected        => fft_event_tlast_unexpected,
      event_tlast_missing           => fft_event_tlast_missing,
      event_data_in_channel_halt    => fft_event_data_in_channel_halt,
      event_data_out_channel_halt   => fft_event_data_out_channel_halt,
      event_status_channel_halt     => fft_event_status_channel_halt
    );
    
fft_status.tready <= '1';

test_fftout.re<= fft_dout.tdata(15 downto 0);
test_fftout.im <= fft_dout.tdata(31 downto 16);

---------------------------------------------------------
-- Filter Coefficients in the Frequency Domain
-- are inplemented as a ROM. This could be implemented as
-- a Loadable RAM, in which case the response would be runtime 
-- Adjustable
-- As it is now, at Design time, I generate the coefs in python and write them
-- to a file, and that file as see below is read at compile time.
-- The filter file contains 16 Bits of I and 16 Bits of Q, written as a
-- single 32 bit word, accessed by a single read address/ strobe 

---------------------------------------------------------

-- All I'm doing here is looking up a piece of data
-- ##As implemented, I did minimal verification of how this works when
-- Axi-S is throttle by the downstream. I think it's OK, because in regards
-- to data flow and control, the ROM setup and mult just look like delays/pipelines

fft_xk_index <= fft_dout.tuser(11 downto 0);
fft_blk_exp  <= fft_dout.tuser(20 downto 16);

rom_addr <= x"00000" & fft_xk_index;

rom_last_addr <= '1' when rom_addr = std_logic_vector(to_unsigned(Nfft-1,32)) else '0';

filter_freq_coefs: inferred_rom 
    generic map (
        depth => Nfft,
        data_in_file => filter_file

    )
    port map (
        clka => aclk,
        ena  => '1',
        addra => rom_addr,
        douta => rom_data
    );


test_rom.re <= rom_data(15 downto 0);
test_rom.im <= rom_data(31 downto 16);
---------------------------------------------------------
-- Delay Forward FFT outputs 1 Clock,
-- because I use the Xk data as an address to the ROM,
-- and the ROM takes 1 clock to drive the data lines from
-- the specified address.
---------------------------------------------------------

-- FFT Dout is:
--         -----------------------------
-- tdata   X  Coef 0  X  Coef 1  X  Coef 2
--         -----------------------------
-- tuser   X    0     X    1     X    2
--         -------------------------------

-- ROM Dout is:
--         ---------------------------------------
-- data    X        Coef 0       X  Coef 1  X Coef 2
--         ---------------------------------------
-- addr    X    0     X    1     X   2      X   3
--         ---------------------------------------

-- The ROM takes 1 clock to turn address into data
-- The ROM ADDR is fft_dout.tuser, which is Freq Bin
-- So to line up operands at Mult input delay FFT output data by 1 clk cyclk

fft_dout_proc:process(aclk)
begin
if rising_edge(aclk) then
    if aresetn = '0' then
        fft_dout_dly1.tdata <= (others=>'0');
        fft_dout_dly1.tvalid <= '0';
        fft_dout_dly1.tlast <= '0';
        rom_last_data <= '0';
    else
        rom_last_data <= rom_last_addr;
        fft_dout_dly1.tdata <= fft_dout.tdata;
        fft_dout_dly1.tvalid <= fft_dout.tvalid;
        fft_dout_dly1.tlast <= fft_dout.tlast;
        fft_dout_dly1.tuser <= fft_dout.tuser;
    end if;
end if;
end process;

fft_dout.tready <= '1';

---------------------------------------------------------
-- Complex Multiplier
---------------------------------------------------------
    
cmpy_inst : cmpy_0
  PORT MAP (
    aclk => aclk,
    aresetn => aresetn,
    s_axis_a_tvalid => fft_dout_dly1.tvalid,
    s_axis_a_tuser => fft_dout_dly1.tuser,
    s_axis_a_tlast => fft_dout_dly1.tlast,
    s_axis_a_tdata => fft_dout_dly1.tdata,
    s_axis_b_tvalid => '1',
    s_axis_b_tlast => rom_last_data,
    s_axis_b_tdata => rom_data,
    m_axis_dout_tvalid => mult_dout.tvalid,
    m_axis_dout_tuser => mult_dout.tuser,
    m_axis_dout_tlast => mult_dout.tlast,
    m_axis_dout_tdata => mult_dout_dlong
  );
  
 -- IMAG is 63 to 32
 -- REAL is 31 to 0

-- Natural width is 33 each truncate to 32 drops the LSB
-- A+jB * C+jD = AC-BD + j(BC+AD)
-- AC is 1.15 x 1.15 = 2.30, AC + BD is then 3.30
-- drop the LSB and you have 3.29
-- which means if you are smart you choose 2 bits down?

-- There is something I don't understand, because I had to set cmpybg=1

 mult_dout.tdata(31 downto 16) <= mult_dout_dlong(63-cmpy_bg downto 48-cmpy_bg);
 mult_dout.tdata(15 downto 0)  <= mult_dout_dlong(31-cmpy_bg downto 16-cmpy_bg);
 
 
 test_multout.re<= mult_dout.tdata(15 downto 0);
 test_multout.im <= mult_dout.tdata(31 downto 16);
 
 
 ---------------------------------------------------------
 -- AXI-Stream Data Fifo
 -- Because after accepting the first input sample of the very first transform operation
 -- Xilinx' FFT Core Might drop TREADY for a single clock cycle
 -- Despite supposedly being "Real Time". THIS IS SO GD ANNOYING.
 -- It forces you to use the AXI-Stream 2-way handshake (tvalid and tready)
 -- on the upstream side of the FFT, which forces one to design for
 -- 2-way flow control.
 -- Drop in this Fifo and ensure that the downstream NEVER blocks deeper
 -- than it's depth. Garbage.
 ---------------------------------------------------------
 
fifo_instance : axis_data_fifo_32_x16
   PORT MAP (
     s_axis_aresetn => aresetn,
     s_axis_aclk => aclk,
     s_axis_tvalid => mult_dout.tvalid,
     s_axis_tready => mult_dout.tready,
     s_axis_tdata => mult_dout.tdata,
     s_axis_tuser => mult_dout.tuser,
     s_axis_tlast => mult_dout.tlast,
     m_axis_tvalid => fifo_dout.tvalid,
     m_axis_tready => fifo_dout.tready,
     m_axis_tdata => fifo_dout.tdata,
     m_axis_tuser => fifo_dout.tuser,
     m_axis_tlast => fifo_dout.tlast,
     axis_data_count => axis_data_count,
     axis_wr_data_count => axis_wr_data_count,
     axis_rd_data_count => axis_rd_data_count
   );
   
blah_proc:process(aclk)
variable waddr : integer range 0 to 7;
variable raddr : integer range 0 to 7;

begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            null;
            waddr := 0;
            raddr := 0;
            ifft_once_per_frame <= '0';
            fft_once_per_frame <= '0';
            blk_exp_ram <= (others => (others => '0'));
        else
            if fifo_dout.tvalid = '1' and fifo_dout.tready = '1' then
                if fft_once_per_frame = '0' then 
                    blk_exp_ram(waddr)<= fifo_dout.tuser(20 downto 16);
                    if waddr = 7 then
                        waddr := 0;
                    else
                        waddr := waddr + 1;
                    end if;
                    fft_once_per_frame <= '1';
                end if;
                if fifo_dout.tlast = '1' then
                    fft_once_per_frame <= '0';
                end if;
            end if;
            
            if ifft_dout.tvalid = '1' and ifft_dout.tready = '1' then
                if ifft_once_per_frame = '0' then
                    blk_exp_in <= blk_exp_ram(raddr);
                    if raddr = 7 then
                        raddr := 0;
                    else
                        raddr := raddr + 1;
                    end if;
                    ifft_once_per_frame <= '1';
                end if;
                if ifft_dout.tlast = '1' then
                    ifft_once_per_frame <= '0';
                end if;
            end if;
        end if;
    end if;
end process;
                    
   
---------------------------------------------------------
-- Inverse FFT Core
-- tlast is weakly used to ensure proper framing
-- But as long as the event signals look right...
---------------------------------------------------------
   
ifft_inst : xfft_0
     PORT MAP (
       aclk => aclk,
       aclken => '1',
       aresetn => aresetn,
       s_axis_config_tdata  => ifft_cnfg.tdata,
       s_axis_config_tvalid =>ifft_cnfg.tvalid,
       s_axis_config_tready => ifft_cnfg.tready,
       
       s_axis_data_tdata    => fifo_dout.tdata,
       s_axis_data_tvalid   => fifo_dout.tvalid,
       s_axis_data_tready   => fifo_dout.tready,  -- This is an output to upstream
       s_axis_data_tlast    => fifo_dout.tlast,
       
       m_axis_data_tdata    => ifft_dout.tdata,
       m_axis_data_tuser    => ifft_dout.tuser,
       m_axis_data_tvalid   => ifft_dout.tvalid,
       m_axis_data_tlast    => ifft_dout.tlast,
       m_axis_data_tready    => ifft_dout.tready,
       
       m_axis_status_tdata     => ifft_status.tdata,
       m_axis_status_tvalid    => ifft_status.tvalid,
       m_axis_status_tready     => ifft_status.tready,
             
       
       event_frame_started          => ifft_event_frame_started,
       event_tlast_unexpected       => ifft_event_tlast_unexpected,
       event_tlast_missing          => ifft_event_tlast_missing,
       event_data_in_channel_halt    => ifft_event_data_in_channel_halt,
       event_data_out_channel_halt   => ifft_event_data_out_channel_halt,
       event_status_channel_halt     => ifft_event_status_channel_halt
     );

ifft_status.tready <= '1';

test_ifftout.re<= ifft_dout.tdata(15 downto 0);
test_ifftout.im <= ifft_dout.tdata(31 downto 16);

ifft_xk_index <= ifft_dout.tuser(11 downto 0);
ifft_blk_exp  <= ifft_dout.tuser(20 downto 16);   

ds_axis_inst : discard_samples_axis
       generic map(
         Nfft => Nfft,
         P => P
       )
       port map (
         aresetn => aresetn_oi,
         aclk => aclk,
         aclken => aclken,
         
         s_axis_data_tvalid => ifft_dout.tvalid,
         s_axis_data_tready => ifft_dout.tready,         --this is an out to upstream
         s_axis_data_tdata => ifft_dout.tdata,
         
         m_axis_data_tvalid => sbt_dout.tvalid,
         m_axis_data_tready => sbt_dout.tready,
         m_axis_data_tlast  => sbt_dout.tlast,
         m_axis_data_tdata => sbt_dout.tdata
       );
 
 test_sbtout.re<= sbt_dout.tdata(15 downto 0);
 test_sbtout.im <= sbt_dout.tdata(31 downto 16); 
 
 m_axis_data_tvalid <= sbt_dout.tvalid;
 sbt_dout.tready <= m_axis_data_tready;
 m_axis_data_tdata <= sbt_dout.tdata;
 --m_axis_data_tlast <= sbt_dout.tlast;
 
end structural;
