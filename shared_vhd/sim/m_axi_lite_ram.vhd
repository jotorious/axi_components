library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity m_axi_lite_ram is
	generic (
		C_M_AXI_ADDR_WIDTH	: integer	:= 13;
		C_M_AXI_DATA_WIDTH	: integer	:= 32

	);
	port (

		M_AXI_ACLK	: in std_logic;
		M_AXI_ARESETN	: in std_logic;

        M_AXI_AWADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_AWPROT	: out std_logic_vector(2 downto 0);
		M_AXI_AWVALID	: out std_logic;
		M_AXI_AWREADY	: in std_logic;

		M_AXI_WDATA	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_WSTRB	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		M_AXI_WVALID	: out std_logic;
		M_AXI_WREADY	: in std_logic;

		M_AXI_BRESP	: in std_logic_vector(1 downto 0);
		M_AXI_BVALID	: in std_logic;
		M_AXI_BREADY	: out std_logic;

		M_AXI_ARADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		M_AXI_ARPROT	: out std_logic_vector(2 downto 0);
		M_AXI_ARVALID	: out std_logic;
		M_AXI_ARREADY	: in std_logic;

		M_AXI_RDATA	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		M_AXI_RRESP	: in std_logic_vector(1 downto 0);
		M_AXI_RVALID	: in std_logic;
		M_AXI_RREADY	: out std_logic;
        done            : out std_logic
	);
end m_axi_lite_ram;

architecture simulation of m_axi_lite_ram is

        
    signal int_axi_AWADDR                   :  std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0) := (others=>'0');
    signal int_axi_AWPROT                   :  std_logic_vector(2 downto 0) := (others=>'0');
    signal int_axi_AWVALID                  :  std_logic := '0';
    signal int_axi_AWREADY                  :  std_logic;
    
    signal int_axi_ARADDR                   :  std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0) := (others=>'0');
    signal int_axi_ARPROT                   :  std_logic_vector(2 downto 0);
    signal int_axi_ARVALID                  :  std_logic := '0';
    signal int_axi_ARREADY                  : std_logic;

    signal int_axi_WDATA                    :  std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0) := (others=>'0');
    signal int_axi_WSTRB                    :  std_logic_vector((C_M_AXI_DATA_WIDTH/8)-1 downto 0) := (others=>'0');
    signal int_axi_WVALID                   :  std_logic  := '0';
    signal int_axi_WREADY                   :  std_logic;
    
    signal int_axi_BRESP                    : std_logic_vector(1 downto 0);
    signal int_axi_BVALID                   : std_logic;
    signal int_axi_BREADY                   :  std_logic := '0';
    
    signal int_axi_RDATA                    : std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal int_axi_RRESP                    : std_logic_vector(1 downto 0);
    signal int_axi_RVALID                   : std_logic;
    signal int_axi_RREADY                   :  std_logic := '0';

    signal int_axi_ACLK                     : std_logic;
    signal int_axi_ARESETN                     : std_logic;

    constant test_address : std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0) := '0'& x"000";

    
    signal sendIt : std_logic := '0';
    signal readIt : std_logic := '0';

begin

    int_axi_ACLK <= M_AXI_ACLK;
	int_axi_ARESETN <=	M_AXI_ARESETN;

    M_AXI_AWADDR <= int_axi_AWADDR;
	M_AXI_AWPROT <= int_axi_AWPROT;
	M_AXI_AWVALID  <= int_axi_AWVALID;
	int_axi_AWREADY <= M_AXI_AWREADY;

    M_AXI_ARADDR <= int_axi_ARADDR;
	M_AXI_ARPROT <= int_axi_ARPROT;
	M_AXI_ARVALID  <= int_axi_ARVALID;
	int_axi_ARREADY <= M_AXI_ARREADY;


	M_AXI_WDATA	<= int_axi_WDATA;
	M_AXI_WSTRB	<= int_axi_WSTRB;
	M_AXI_WVALID <=	int_axi_WVALID;
	int_axi_WREADY <= M_AXI_WREADY;

	int_axi_BRESP <= M_AXI_BRESP;
	int_axi_BVALID <= M_AXI_BVALID;
	M_AXI_BREADY <=	int_axi_BREADY;


	int_axi_RDATA <= M_AXI_RDATA;
	int_axi_RRESP <= M_AXI_RRESP;
	int_axi_RVALID <= M_AXI_RVALID;
	M_AXI_RREADY  <= int_axi_RREADY;



 -- Initiate process which simulates a master wanting to write.
 -- This process is blocked on a "Send Flag" (sendIt).
 -- When the flag goes to 1, the process exits the wait state and
 -- execute a write transaction.
 send : PROCESS
 BEGIN
    int_axi_AWVALID<='0';
    int_axi_WVALID<='0';
    int_axi_BREADY<='0';
    loop
        wait until sendIt = '1';
        wait until int_axi_ACLK= '1';
            int_axi_AWVALID<='1';                               -- Indicate Master is driving valid address                                          
            int_axi_WVALID<='1';                                -- Indicate Master is driving valid data
        wait until (int_axi_AWREADY and int_axi_WREADY) = '1';  -- Wait for Slave ready to accept address/data        
            int_axi_BREADY<='1';                                --Indicate master is ready for response
        wait until int_axi_BVALID = '1';                        -- Wait for slave to indicate valid response value
            assert int_axi_BRESP = "00" report "AXI data not written" severity failure;  -- Note Failure on any value not 00
            int_axi_AWVALID<='0';                               -- Indicate Master is not driving valid address
            int_axi_WVALID<='0';                                -- Indicate MAster is not driving valid data            
            int_axi_BREADY<='1';
        wait until int_axi_BVALID = '0';  -- All finished
            int_axi_BREADY<='0';
    end loop;
 END PROCESS send;

  -- Initiate process which simulates a master wanting to read.
  -- This process is blocked on a "Read Flag" (readIt).
  -- When the flag goes to 1, the process exits the wait state and
  -- execute a read transaction.
  read : PROCESS
  BEGIN
    int_axi_ARVALID<='0';
    int_axi_RREADY<='0';
     loop
         wait until readIt = '1';
         wait until int_axi_ACLK= '1';
             int_axi_ARVALID<='1';
             int_axi_RREADY<='1';
         --wait until (int_axi_RVALID and int_axi_ARREADY) = '1';  --Client provided data
         wait until int_axi_ARREADY = '1';
         wait until int_axi_RVALID = '1';
            assert int_axi_RRESP = "00" report "AXI data not written" severity failure;
            --int_axi_RREADY<='0';
            int_axi_ARVALID<='0';
            wait until int_axi_ACLK= '1';
            int_axi_RREADY<='0';
     end loop;
  END PROCESS read;


 -- 
 tb : PROCESS
 BEGIN
        done <= '0';
        sendIt<='0';
    -- Write Bins
    wait until int_axi_ARESETN = '1';

        int_axi_AWADDR<='0'& x"020";
        int_axi_WDATA<=x"00000008";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
    
    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
            
        int_axi_AWADDR<='0'& x"004";
        int_axi_WDATA<=x"00000000";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';

    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"008";
        int_axi_WDATA<=x"00000000";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';

    -- Write Stack Add    

    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"007";
        int_axi_WDATA<=x"00000040";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"004";
        int_axi_WDATA<=x"00000400";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"005";
        int_axi_WDATA<=x"00000100";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"00C";
        int_axi_WDATA<=x"00000002";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
    
    wait until int_axi_BVALID = '0';  --AXI Write finished
        int_axi_WSTRB<=b"0000";
        
        int_axi_AWADDR<='0'& x"008";
        int_axi_WDATA<=x"00000000";
        int_axi_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until int_axi_BVALID = '1';
   
    wait until int_axi_BVALID = '0';  --AXI Write finished

        int_axi_WSTRB<=b"0000";        
        int_axi_ARADDR<='0'& x"010";
        readIt<='1';                --Start AXI Read from Slave
        wait for 1 ns;
        readIt<='0'; --Clear "Start Read" Flag
    wait until int_axi_RVALID = '1';
    wait until int_axi_RVALID = '0';
        int_axi_ARADDR<='0'&x"014";
        readIt<='1';                --Start AXI Read from Slave
        wait for 1 ns;
        readIt<='0'; --Clear "Start Read" Flag
    wait until int_axi_RVALID = '1';
    wait until int_axi_RVALID = '0';
    
    done <= '1';    
    wait; -- will wait forever
 END PROCESS tb;

end simulation;
