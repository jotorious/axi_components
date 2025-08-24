library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axis_packet_mux_pkg is

type type_tvalid is array (natural range <>) of std_logic;
type type_tready is array (natural range <>) of std_logic;
type type_tlast is array (natural range <>) of std_logic;
type type_tdata is array (natural range <>) of std_logic_vector(31 downto 0);
type type_tuser is array (natural range <>) of std_logic_vector(15 downto 0);
type type_tstrb is array (natural range <>) of std_logic_vector(3 downto 0);

--type_tdata is array (natural_range <>) of std_logic_vector;
--type_tuser is array (natural_range <>) of std_logic_vector;
--type_tstrb is array (natural_range <>) of std_logic_vector;

end axis_packet_mux_pkg;
