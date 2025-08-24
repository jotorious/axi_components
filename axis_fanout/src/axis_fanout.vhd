library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_wrapper_pkg.all;
use work.axis_packet_mux_pkg.all;

entity axis_fanout is
	generic (
		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_M_AXIS_TUSER_WIDTH	: integer	:= 16;
		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
        C_S_AXIS_TUSER_WIDTH	: integer	:= 16;
        NUM_MASTERS               : integer   := 4
	);
	port (
		-- Ports of Axi Slave Bus Interface S00_AXIS
		s_axis_aclk	: in std_logic;
		s_axis_aresetn	: in std_logic;

        s_axis_tready	: out std_logic;
		s_axis_tdata	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        s_axis_tuser    : in std_logic_vector(C_S_AXIS_TUSER_WIDTH-1 downto 0);
        s_axis_tstrb	: in std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tvalid	: in std_logic;

        -- Ports of Axi Master Bus Interface M00_AXIS
		m_axis_tvalid	: out type_tvalid(0 to NUM_MASTERS-1);
		m_axis_tdata	: out type_tdata(0 to NUM_MASTERS-1);
		m_axis_tstrb	: out type_tstrb(0 to NUM_MASTERS-1);
        m_axis_tuser	: out type_tuser24(0 to NUM_MASTERS-1);
		m_axis_tlast	: out type_tlast(0 to NUM_MASTERS-1);
		m_axis_tready	: in type_tready(0 to NUM_MASTERS-1)

	);
end axis_fanout;

architecture arch_imp of axis_fanout is

signal din : std_logic_vector(31 downto 0);
signal din_en :std_logic;
signal din_last :std_logic;

signal dout_sw : std_logic_vector(31 downto 0);
signal dout_en_sw :std_logic;
signal dout_last_sw :std_logic;
signal dout_index_sw :std_logic_vector(23 downto 0);
    
signal dout: type_tdata(0 to NUM_MASTERS-1);
signal dout_en :type_tvalid(0 to NUM_MASTERS-1);
signal dout_last: type_tlast(0 to NUM_MASTERS-1);
signal dout_index: type_tuser24(0 to NUM_MASTERS-1);

signal u_fifo_empty, u_fifo_al_empty, u_fifo_rden : std_logic;

signal d_fifo_full, d_fifo_almost_full, d_not_almost_full : type_tvalid(0 to NUM_MASTERS-1);

signal internal_fifo_status : std_logic_vector(7 downto 0);

signal testme : std_logic_vector(3 downto 0) := "0000";

begin

axis_wrapper_saxis_inst : axis_wrapper_saxis
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_S_AXIS_TDATA_WIDTH,
        C_S_AXIS_TUSER_WIDTH	=> 16,
        FIFO_MAX_DEPTH => 8,
        FIFO_PROG_EMPTY => 3
	)
	port map (
	    dout            => din,
        dout_last       => din_last,
        fifo_rden =>u_fifo_rden,
        fifo_empty => u_fifo_empty,
        fifo_almost_empty => u_fifo_al_empty,
	
		S_AXIS_ACLK	    => s_axis_aclk,
		S_AXIS_ARESETN	=> s_axis_aresetn,
		S_AXIS_TREADY	=> s_axis_tready,
		S_AXIS_TDATA	=> s_axis_tdata,
        S_AXIS_TUSER	=> (others=> '0'),
		S_AXIS_TSTRB	=> s_axis_tstrb,
		S_AXIS_TLAST	=> s_axis_tlast,
		S_AXIS_TVALID	=> s_axis_tvalid
	);

    din_en <= u_fifo_rden and not u_fifo_empty;


    u_fifo_rden <=  ( d_not_almost_full(0)   and
                      d_not_almost_full(1) ) and
                    ( d_not_almost_full(2)   and
                      d_not_almost_full(3) );




main_proc: process(s_axis_aclk)
begin
    if rising_edge(s_axis_aclk) then
        if s_axis_aresetn = '0' then
            dout_last_sw <= '0';
            dout_en_sw <= '0';
            dout_sw <= (others => '0');
            testme <= "0001";
        else
            if din_en = '1' then
                dout_sw <= din;
                dout_en_sw <= '1';
                
                if din_last = '1' then
                    dout_last_sw <= '1';
                    testme <= "0010";
                else
                    testme <= "0110";
                    dout_last_sw <= '0';
                end if;
            else
                testme <= "0011";
                dout_sw <= dout_sw;
                dout_last_sw <= '0';
                dout_en_sw <= '0';
            end if;
        end if;
    end if;
end process;

maxis_instances: for i in 0 to NUM_MASTERS - 1 generate

axis_wrapper_maxis_inst : axis_wrapper_maxis
        generic map (
            C_M_AXIS_TDATA_WIDTH    => C_M_AXIS_TDATA_WIDTH,
            C_M_AXIS_TUSER_WIDTH    => 24,
            FIFO_MAX_DEPTH => 16,
            FIFO_PROG_FULL => 5
        )
        port map (
            din => dout(i),
            din_en =>dout_en(i),
            din_last => dout_last(i),
            din_user => dout_index(i),
            fifo_full => d_fifo_full(i),
            fifo_almost_full => d_fifo_almost_full(i),
                
            M_AXIS_ACLK    => s_axis_aclk,
            M_AXIS_ARESETN    => s_axis_aresetn,
            M_AXIS_TVALID    => m_axis_tvalid(i),
            M_AXIS_TDATA    => m_axis_tdata(i),
            M_AXIS_TUSER    => m_axis_tuser(i),
            M_AXIS_TSTRB    => m_axis_tstrb(i),
            M_AXIS_TLAST    => m_axis_tlast(i),
            M_AXIS_TREADY    => m_axis_tready(i)
        );

d_not_almost_full(i) <= not d_fifo_almost_full(i);

dout_en(i)    <= dout_en_sw;
dout(i)       <= dout_sw;
dout_last(i)  <= dout_last_sw;
dout_index(i) <= dout_index_sw; 


end generate;
        
end arch_imp;
