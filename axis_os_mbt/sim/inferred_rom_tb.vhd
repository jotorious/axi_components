-- TestBench Template 

  LIBRARY ieee;
  USE ieee.std_logic_1164.ALL;
  USE ieee.numeric_std.ALL;


  ENTITY inferred_rom_tb IS
  END inferred_rom_tb;

  ARCHITECTURE behavior OF inferred_rom_tb IS 

  -- Component Declaration
    component inferred_rom
	    GENERIC (
            depth : integer := 2048;
		    data_in_file: string    := "filter_coefs.coe" 
	    );
	    PORT (
		    clka : IN STD_LOGIC;
		    ena : IN STD_LOGIC;
		    addra : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	    );
    end component;
	
	--DUT Input Signals
	signal tb_clk, tb_clk_en							: std_logic;
	signal tb_xn_re, tb_xn_im		: std_logic_vector (15 downto 0);
	--Output Signals
	signal tb_xk_re, tb_xk_im 						: std_logic_vector (15 downto 0);
	signal tb_xn_index, tb_xk_index				: std_logic_vector ( 9 downto 0);
	--testbed internal
	signal tb_rst : std_logic;
	
	alias tb_din : std_logic_vector(11 downto 0) is tb_xn_re(15 downto 4);
	alias tb_dout: std_logic_vector(11 downto 0) is tb_xk_re(15 downto 4);
    
    signal tb_dout32 : std_logic_vector(31 downto 0);
    signal tb_addr : std_logic_vector(31 downto 0);
          

  BEGIN

  -- Component Instantiation
DUT: inferred_rom 
	    generic map (
            depth => 2048,
		    data_in_file => "filter_coefs.coe" 
	    )
	    port map (
		    clka => tb_clk,
		    ena  => '1',
		    addra => tb_addr,
		    douta => tb_dout32
	    );




  --  Test Bench Statements
     clk_proc : PROCESS
     BEGIN
			tb_clk <= '0';
			wait for 5 ns; -- wait until global set/reset completes
			tb_clk <= '1';
			wait for 5 ns;
     END PROCESS;
	  
	  rst_proc : PROCESS
     BEGIN
			tb_rst <= '1';
			tb_clk_en  <= '0';
			wait for 12 ns; -- wait until global set/reset completes
			tb_rst <= '0';
			wait for 16 ns;
			tb_clk_en  <= '1';
			wait;
     END PROCESS;	  

    addr_proc : process(tb_clk,tb_rst)
    variable count : integer range 0 to 65536; 
    begin
    if tb_rst = '1' then
        count := 0;
    elsif rising_edge(tb_clk) then
        count := count + 1;
        tb_addr <= std_logic_vector(to_unsigned(count, 32));
    end if;
    end process;
    

  --  End Test Bench 
  END;
