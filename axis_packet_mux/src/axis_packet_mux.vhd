library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;
use work.axis_packet_mux_pkg.all;

entity axis_packet_mux is
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        NUM_SLAVES               : integer   := 4
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

		s_axis_tready	: out type_tready(0 to NUM_SLAVES-1);
		s_axis_tdata	: in type_tdata(0 to NUM_SLAVES-1);
        s_axis_tuser    : in type_tuser(0 to NUM_SLAVES-1);
        s_axis_tstrb	: in type_tstrb(0 to NUM_SLAVES-1);
		s_axis_tlast	: in type_tlast(0 to NUM_SLAVES-1);
		s_axis_tvalid	: in type_tvalid(0 to NUM_SLAVES-1);

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		m_axis_tstrb	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
        m_axis_tuser	: out std_logic_vector(C_M_AXIS_TUSER_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end axis_packet_mux;

architecture arch_imp of axis_packet_mux is



signal din : type_tdata(0 to NUM_SLAVES-1);
signal din_en: type_tvalid(0 to NUM_SLAVES-1);
signal din_last: type_tlast(0 to NUM_SLAVES-1);

signal din_sw : std_logic_vector(31 downto 0);
signal din_en_sw :std_logic;
signal din_last_sw :std_logic;
    
signal dout: std_logic_vector(31 downto 0);
signal dout_en :std_logic;
signal dout_last: std_logic;
signal dout_index: std_logic_vector(15 downto 0);

signal u_fifo_empty, u_fifo_al_empty, u_fifo_rden : type_tvalid(0 to NUM_SLAVES-1);
signal d_fifo_full, d_fifo_almost_full, d_not_almost_full : std_logic;

signal internal_fifo_status : std_logic_vector(7 downto 0);

signal curr_switch_control : std_logic_vector(1 downto 0) := "00";
signal switch_control : std_logic_vector(1 downto 0);

signal testme : std_logic_vector(3 downto 0) := "0000";

begin

saxis_instances: for i in 0 to NUM_SLAVES - 1 generate

axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,
        C_S_AXIS_TUSER_WIDTH	=> 16,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_EMPTY => 3
	)
	port map (
	    dout            => din(i),
        dout_last       => din_last(i),
        fifo_rden =>u_fifo_rden(i),
        fifo_empty => u_fifo_empty(i),
        fifo_almost_empty => u_fifo_al_empty(i),
	
		S_AXIS_ACLK	    => s_axis_aclk,
		S_AXIS_ARESETN	=> s_axis_aresetn,
		S_AXIS_TREADY	=> s_axis_tready(i),
		S_AXIS_TDATA	=> s_axis_tdata(i),
        S_AXIS_TUSER	=> (others=> '0'),
		S_AXIS_TSTRB	=> s_axis_tstrb(i),
		S_AXIS_TLAST	=> s_axis_tlast(i),
		S_AXIS_TVALID	=> s_axis_tvalid(i)
	);

    din_en(i) <= u_fifo_rden(i) and not u_fifo_empty(i);


    u_fifo_rden(i) <= d_not_almost_full when unsigned(switch_control) = i else '0';

end generate;


main_proc: process(s_axis_aclk)
begin
    if rising_edge(s_axis_aclk) then
        if s_axis_aresetn = '0' then
            dout_last <= '0';
            dout_en <= '0';
            dout <= (others => '0');
            curr_switch_control <= "00";
            testme <= "0001";

        else
            if din_en_sw = '1' then
                dout <= din_sw;
                dout_en <= '1';
                
                if din_last_sw = '1' then
                    dout_last <= '1';
                    if unsigned(curr_switch_control) = 3 then
                        testme <= "0010";
                        curr_switch_control <= "00";
                    else
                        testme <= "0011";
                        curr_switch_control <= std_logic_vector(unsigned(curr_switch_control) + 1);
                    end if;
                else
                    testme <= "0110";
                    dout_last <= '0';
                end if;
            else
                testme <= "0011";
                dout <= dout;
                dout_last <= '0';
                dout_en <= '0';
            end if;
        end if;
    end if;
end process;

switch_control <= curr_switch_control;

din_sw(31 downto 0) <=  din(0) when unsigned(switch_control) = 0 else
                        din(1) when unsigned(switch_control) = 1 else
                        din(2) when unsigned(switch_control) = 2 else
                        din(3) when unsigned(switch_control) = 3 else
                        (others=>'0');

din_en_sw           <=  din_en(0) when unsigned(switch_control) = 0 else
                        din_en(1) when unsigned(switch_control) = 1 else
                        din_en(2) when unsigned(switch_control) = 2 else
                        din_en(3) when unsigned(switch_control) = 3 else
                        '0';

din_last_sw         <=  din_last(0) when unsigned(switch_control) = 0 else
                        din_last(1) when unsigned(switch_control) = 1 else
                        din_last(2) when unsigned(switch_control) = 2 else
                        din_last(3) when unsigned(switch_control) = 3 else
                        '0';



axis_wrapper_maxis_inst : axis_wrapper_maxis
        generic map (
            C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
            C_M_AXIS_TUSER_WIDTH    => 16,
            FIFO_MAX_DEPTH => 16,
            FIFO_PROG_FULL => 5
        )
        port map (
            din => dout,
            din_en =>dout_en,
            din_last => dout_last,
            din_user => dout_index,
            fifo_full => d_fifo_full,
            fifo_almost_full => d_fifo_almost_full,
                
            M_AXIS_ACLK    => s_axis_aclk,
            M_AXIS_ARESETN    => s_axis_aresetn,
            M_AXIS_TVALID    => m_axis_tvalid,
            M_AXIS_TDATA    => m_axis_tdata,
            M_AXIS_TUSER    => m_axis_tuser,
            M_AXIS_TSTRB    => m_axis_tstrb,
            M_AXIS_TLAST    => m_axis_tlast,
            M_AXIS_TREADY    => m_axis_tready
        );

d_not_almost_full <= not d_fifo_almost_full;

           
end arch_imp;
