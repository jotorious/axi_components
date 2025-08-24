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

use ieee.std_logic_textio.all;  
library std;
use STD.textio.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity s_axis_verifysink is
    generic (
        PKTLEN : integer;
        PKTS_TO_SINK : integer;
        outfname : string := "outfile.dat";
        verfname : string := "infile.dat";
        CPS : integer
    );
    port (
-- Global ports
		S_AXIS_ACLK	: in std_logic;
		S_AXIS_ARESETN	: in std_logic;
 
		S_AXIS_TVALID	: in std_logic;
		S_AXIS_TDATA	: in std_logic_vector(31 downto 0);
		S_AXIS_TUSER	: in std_logic_vector(15 downto 0);
		S_AXIS_TSTRB	: in std_logic_vector(3 downto 0);

		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TREADY	: out std_logic;

        samples_written : out integer;

        done            : out boolean
    );
end s_axis_verifysink;

architecture tb of s_axis_verifysink is

  --file outfile : text open write_mode is "sbt_testout.data";
  file outfile : text open write_mode is outfname; 
  file infile : text open read_mode is verfname;
  signal tready : std_logic := '0';
  signal tvalid : std_logic;
  signal aclk : std_logic;
  signal aresetn : std_logic;
  signal tdata : std_logic_vector(31 downto 0);
  signal dout_re :std_logic_vector(15 downto 0);
  signal dout_im :std_logic_vector(15 downto 0);


  --constant CPS : integer := 4 ; --Clocks per sample
  signal samples_written_i : integer := 0;

  signal i_done : boolean := FALSE;

  constant SAMPLES_TO_SINK : integer := PKTS_TO_SINK *PKTLEN;
  
 

begin

    
------------------------
--Data out process
------------------------

-- in ports to signals
aclk    <= S_AXIS_ACLK;
aresetn <= S_AXIS_ARESETN;
tvalid  <= S_AXIS_TVALID;
tdata   <= S_AXIS_TDATA;

-- signal to out ports
S_AXIS_TREADY <= tready;

samples_written <= samples_written_i;


dout_re <= tdata(15 downto 0);
dout_im <= tdata(31 downto 16);

done <= i_done;

dout_proc: process(aclk)
    variable outline: line;
    variable vvalid: boolean;
    variable outdata: std_logic_vector(15 downto 0);
    variable file_count : integer := 0;

    variable inline: line;
    variable vvalid2: boolean;
    variable indata: std_logic_vector(15 downto 0);

begin
    if rising_edge(aclk) then
	    if aresetn = '0' then
	        file_count := 0;
            samples_written_i <= 0;
            i_done <= FALSE;
        else
            if samples_written_i = SAMPLES_TO_SINK then
                report "DONE, NO BAD VALUES";
                i_done <= TRUE;
            end if;
                
            if (tvalid = '1' and tready = '1') then
                -- Write testdata out
		        outdata := dout_re;
		        hwrite(outline,outdata);
		        writeline(outfile,outline);
                
                -- Read file in
                readline(infile,inline);
                hread(inline,indata);

                --compare out and in
                assert (indata = dout_re) report "Unexpected Output Value1" severity FAILURE;

		        -- Write testdata out
		        outdata := dout_im;
		        hwrite(outline,outdata);
		        writeline(outfile,outline);

                -- Read file in
                readline(infile,inline);
                hread(inline,indata);

                --compare out and in
                assert (indata = dout_im) report "Unexpected Output Value2" severity FAILURE;

		        file_count := file_count + 1;
            end if;
            samples_written_i <= file_count;
	    end if;
    end if;
end process;

--tready <= '1';

ctrl_proc: process(aclk)
variable count : integer;
begin
    if rising_edge(aclk) then
	    if aresetn = '0' then
	        count := 0;
            tready <= '0';
        else
            count := count + 1;
            if count = CPS then                
                if tvalid = '1' then
                    count := 0;
                    tready <= '1';
                else
                    count := count - 1;
                end if;
            else
                tready <= '0';
            end if;

	    end if;
    end if;
end process; 


end tb;
