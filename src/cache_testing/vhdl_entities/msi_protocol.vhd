library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity msi_protocol is
    port (
        clk             : in std_logic;
        reset           : in std_logic;
        cpu0_state      : in std_logic_vector(1 downto 0); -- MSI state for cpu0
        cpu1_state      : in std_logic_vector(1 downto 0); -- MSI state for cpu1
        cpu0_addr       : in std_logic_vector(31 downto 0);   -- Address from cpu0
        cpu1_addr       : in std_logic_vector(31 downto 0);   -- Address from cpu1
        invalidate_cpu0 : out std_logic;                      -- Invalidate signal for cpu0
        invalidate_cpu1 : out std_logic                       -- Invalidate signal for cpu1
    );
end msi_protocol;

architecture Behavioral of msi_protocol is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            invalidate_cpu0 <= '0';
            invalidate_cpu1 <= '0';
        elsif rising_edge(clk) then
            -- If CPU0 modifies a cache line, invalidate the corresponding line in CPU1
            if cpu0_state = "10" then -- Modified state in cpu0
                if cpu1_state = "01" and cpu0_addr = cpu1_addr then -- Shared state in cpu1 for the same address
                    invalidate_cpu1 <= '1'; -- Invalidate the cache line in cpu1
                else
                    invalidate_cpu1 <= '0';
                end if;
            end if;
            
            -- If CPU1 modifies a cache line, invalidate the corresponding line in CPU0
            if cpu1_state = "10" then -- Modified state in cpu1
                if cpu0_state = "01" and cpu1_addr = cpu0_addr then -- Shared state in cpu0 for the same address
                    invalidate_cpu0 <= '1'; -- Invalidate the cache line in cpu0
                else
                    invalidate_cpu0 <= '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;
