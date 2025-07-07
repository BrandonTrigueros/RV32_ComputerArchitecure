library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram is
    port(
        clk        : in  std_logic;
        reset      : in  std_logic;
        operation1 : in  std_logic;                     -- 0=read, 1=write on port1
        operation2 : in  std_logic;                     -- 0=read, 1=write on port2
        ready1     : in  std_logic;                     -- handshake from CPU1
        ready2     : in  std_logic;                     -- handshake from CPU2
        addr1      : in  std_logic_vector(2 downto 0);
        addr2      : in  std_logic_vector(2 downto 0);
        data_in1   : in  std_logic_vector(31 downto 0); -- CPU→SDRAM data
        data_in2   : in  std_logic_vector(31 downto 0);
        data_out1  : out std_logic_vector(31 downto 0); -- SDRAM→CPU data
        data_out2  : out std_logic_vector(31 downto 0)
    );
end sdram;

architecture Behavioral of sdram is
    type memory_array is array (0 to 7) of std_logic_vector(31 downto 0);
    signal memory : memory_array;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Initialize memory with test pattern
            memory(0) <= x"00000000";
            memory(1) <= x"11111111";
            memory(2) <= x"22222222";
            memory(3) <= x"33333333";
            memory(4) <= x"44444444";
            memory(5) <= x"55555555";
            memory(6) <= x"66666666";
            memory(7) <= x"77777777";
        elsif rising_edge(clk) then
            -- Port 1 operations
            if ready1 = '1' then
                if operation1 = '1' then
                    -- Write
                    memory(to_integer(unsigned(addr1))) <= data_in1;
                else
                    -- Read
                    data_out1 <= memory(to_integer(unsigned(addr1)));
                end if;
            end if;
            
            -- Port 2 operations
            if ready2 = '1' then
                if operation2 = '1' then
                    -- Write
                    memory(to_integer(unsigned(addr2))) <= data_in2;
                else
                    -- Read
                    data_out2 <= memory(to_integer(unsigned(addr2)));
                end if;
            end if;
        end if;
    end process;
end Behavioral;
