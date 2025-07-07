library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CPU_Core is
    port (
        clk            : in std_logic;
        reset          : in std_logic;
        priority       : in std_logic;
        
        -- CPU interface
        wantedAddress  : in std_logic_vector(2 downto 0);
        
        -- SDRAM interface
        read_en        : out std_logic;
        write_en       : out std_logic;
        Sdram_addr     : out std_logic_vector(2 downto 0);
        Sdram_data_in  : in std_logic_vector(31 downto 0);
        Sdram_data_out : out std_logic_vector(31 downto 0);
        
        -- MSI protocol - outgoing requests
        cpu_wr_req_out : out std_logic;
        cpu_rd_req_out : out std_logic;
        cpu_req_addr_out : out std_logic_vector(2 downto 0);
        
        -- MSI protocol - incoming requests (snooping)
        cpu_wr_req_in  : in std_logic;
        cpu_rd_req_in  : in std_logic;
        cpu_req_addr_in : in std_logic_vector(2 downto 0);
        
        -- Cache-to-cache communication - outgoing
        cache_to_cache_req_out : out std_logic;
        cache_to_cache_req_address_out : out std_logic_vector(2 downto 0);
        cache_to_cache_resp_out : out std_logic;
        cache_to_cache_resp_out_ready : out std_logic;
        cache_to_cache_resp_out_data : out std_logic_vector(31 downto 0);
        
        -- Cache-to-cache communication - incoming
        cache_to_cache_req_in : in std_logic;
        cache_to_cache_req_address_in : in std_logic_vector(2 downto 0);
        cache_to_cache_resp_in : in std_logic;
        cache_to_cache_resp_in_ready : in std_logic;
        cache_to_cache_resp_in_data : in std_logic_vector(31 downto 0)
    );
end CPU_Core;

architecture Behavioral of CPU_Core is
    -- Cache configuration
    constant CACHE_SIZE : integer := 4;
    
    -- MSI states
    type msi_state_type is (MSI_INVALID, MSI_SHARED, MSI_MODIFIED);
    
    -- Cache line structure
    type cache_line_type is record
        msi_state : msi_state_type;
        address   : std_logic_vector(2 downto 0);
        data      : std_logic_vector(31 downto 0);
        valid     : std_logic;
    end record;
    
    type cache_array_type is array (0 to CACHE_SIZE-1) of cache_line_type;
    
    -- CPU operation states
    type cpu_state_type is (CPU_IDLE, CPU_READ, CPU_WRITE, CPU_WAIT_CACHE, CPU_WAIT_SDRAM);
    
    -- Cache operation states  
    type cache_state_type is (CACHE_CHECK, CACHE_HIT, CACHE_MISS, CACHE_COHERENCE, CACHE_SDRAM_ACCESS);
    
    -- Signals
    signal cache_mem : cache_array_type;
    signal cpu_state : cpu_state_type;
    signal cache_state : cache_state_type;
    signal current_address : std_logic_vector(2 downto 0);
    signal current_data : std_logic_vector(31 downto 0);
    signal cache_hit_flag : std_logic;
    signal cache_hit_index : integer range 0 to CACHE_SIZE-1;
    signal evict_index : integer range 0 to CACHE_SIZE-1;
    signal operation_type : std_logic; -- 0 = read, 1 = write
    signal cycle_counter : integer range 0 to 15;
    
    -- Helper functions
    function find_cache_line(addr : std_logic_vector(2 downto 0); cache_mem : cache_array_type) 
        return integer is
    begin
        for i in 0 to CACHE_SIZE-1 loop
            if cache_mem(i).valid = '1' and cache_mem(i).address = addr then
                return i;
            end if;
        end loop;
        return -1; -- Not found
    end function;
    
    function find_empty_line(cache_mem : cache_array_type) return integer is
    begin
        for i in 0 to CACHE_SIZE-1 loop
            if cache_mem(i).valid = '0' then
                return i;
            end if;
        end loop;
        return -1; -- Cache full
    end function;

begin

    -- Main cache controller process
    main_process: process(clk, reset)
        variable hit_index : integer;
        variable empty_index : integer;
    begin
        if reset = '1' then
            -- Initialize cache
            for i in 0 to CACHE_SIZE-1 loop
                cache_mem(i).msi_state <= MSI_INVALID;
                cache_mem(i).address <= (others => '0');
                cache_mem(i).data <= (others => '0');
                cache_mem(i).valid <= '0';
            end loop;
            
            -- Reset state machines
            cpu_state <= CPU_IDLE;
            cache_state <= CACHE_CHECK;
            
            -- Reset outputs
            read_en <= '0';
            write_en <= '0';
            cpu_wr_req_out <= '0';
            cpu_rd_req_out <= '0';
            cache_to_cache_req_out <= '0';
            cache_to_cache_resp_out <= '0';
            cache_to_cache_resp_out_ready <= '0';
            
            evict_index <= 0;
            cycle_counter <= 0;
            
        elsif rising_edge(clk) then
            -- Default signal values
            read_en <= '0';
            write_en <= '0';
            cache_to_cache_req_out <= '0';
            cache_to_cache_resp_out <= '0';
            cache_to_cache_resp_out_ready <= '0';
            
            -- Handle snooping requests from other caches
            if cache_to_cache_req_in = '1' then
                hit_index := find_cache_line(cache_to_cache_req_address_in, cache_mem);
                if hit_index >= 0 then
                    if cache_mem(hit_index).msi_state = MSI_MODIFIED then
                        -- Provide data and transition to shared
                        cache_to_cache_resp_out <= '1';
                        cache_to_cache_resp_out_data <= cache_mem(hit_index).data;
                        cache_mem(hit_index).msi_state <= MSI_SHARED;
                    elsif cache_mem(hit_index).msi_state = MSI_SHARED then
                        -- Provide data, stay shared
                        cache_to_cache_resp_out <= '1';
                        cache_to_cache_resp_out_data <= cache_mem(hit_index).data;
                    end if;
                else
                    cache_to_cache_resp_out <= '0';
                end if;
                cache_to_cache_resp_out_ready <= '1';
            end if;
            
            -- Handle invalidation requests
            if cpu_wr_req_in = '1' then
                hit_index := find_cache_line(cpu_req_addr_in, cache_mem);
                if hit_index >= 0 then
                    cache_mem(hit_index).msi_state <= MSI_INVALID;
                    cache_mem(hit_index).valid <= '0';
                end if;
            end if;
            
            -- Main CPU state machine
            case cpu_state is
                when CPU_IDLE =>
                    cycle_counter <= cycle_counter + 1;
                    
                    -- Simple test pattern
                    if cycle_counter = 5 then
                        cpu_state <= CPU_WRITE;
                        current_address <= wantedAddress;
                        current_data <= x"DEADBEEF";
                        operation_type <= '1'; -- write
                        cpu_wr_req_out <= '1';
                        cpu_req_addr_out <= wantedAddress;
                        cache_state <= CACHE_CHECK;
                        cycle_counter <= 0;
                    elsif cycle_counter = 10 then
                        cpu_state <= CPU_READ;
                        current_address <= wantedAddress;
                        operation_type <= '0'; -- read
                        cpu_rd_req_out <= '1';
                        cpu_req_addr_out <= wantedAddress;
                        cache_state <= CACHE_CHECK;
                        cycle_counter <= 0;
                    end if;
                
                when CPU_READ | CPU_WRITE =>
                    case cache_state is
                        when CACHE_CHECK =>
                            hit_index := find_cache_line(current_address, cache_mem);
                            if hit_index >= 0 and cache_mem(hit_index).msi_state /= MSI_INVALID then
                                -- Cache hit
                                cache_hit_flag <= '1';
                                cache_hit_index <= hit_index;
                                cache_state <= CACHE_HIT;
                            else
                                -- Cache miss
                                cache_hit_flag <= '0';
                                cache_state <= CACHE_MISS;
                            end if;
                        
                        when CACHE_HIT =>
                            if operation_type = '0' then
                                -- Read hit - return data
                                cpu_state <= CPU_IDLE;
                                cpu_rd_req_out <= '0';
                                cache_state <= CACHE_CHECK;
                            else
                                -- Write hit - update data and set modified
                                cache_mem(cache_hit_index).data <= current_data;
                                cache_mem(cache_hit_index).msi_state <= MSI_MODIFIED;
                                cpu_state <= CPU_IDLE;
                                cpu_wr_req_out <= '0';
                                cache_state <= CACHE_CHECK;
                            end if;
                        
                        when CACHE_MISS =>
                            -- Try cache-to-cache transfer first
                            cache_to_cache_req_out <= '1';
                            cache_to_cache_req_address_out <= current_address;
                            cache_state <= CACHE_COHERENCE;
                        
                        when CACHE_COHERENCE =>
                            if cache_to_cache_resp_in_ready = '1' then
                                if cache_to_cache_resp_in = '1' then
                                    -- Cache-to-cache hit
                                    empty_index := find_empty_line(cache_mem);
                                    if empty_index >= 0 then
                                        -- Use empty line
                                        cache_mem(empty_index).valid <= '1';
                                        cache_mem(empty_index).address <= current_address;
                                        cache_mem(empty_index).data <= cache_to_cache_resp_in_data;
                                        if operation_type = '0' then
                                            cache_mem(empty_index).msi_state <= MSI_SHARED;
                                        else
                                            cache_mem(empty_index).msi_state <= MSI_MODIFIED;
                                            cache_mem(empty_index).data <= current_data;
                                        end if;
                                    else
                                        -- Evict using round-robin
                                        if cache_mem(evict_index).msi_state = MSI_MODIFIED then
                                            -- Write back to SDRAM
                                            write_en <= '1';
                                            Sdram_addr <= cache_mem(evict_index).address;
                                            Sdram_data_out <= cache_mem(evict_index).data;
                                        end if;
                                        cache_mem(evict_index).valid <= '1';
                                        cache_mem(evict_index).address <= current_address;
                                        cache_mem(evict_index).data <= cache_to_cache_resp_in_data;
                                        if operation_type = '0' then
                                            cache_mem(evict_index).msi_state <= MSI_SHARED;
                                        else
                                            cache_mem(evict_index).msi_state <= MSI_MODIFIED;
                                            cache_mem(evict_index).data <= current_data;
                                        end if;
                                        evict_index <= (evict_index + 1) mod CACHE_SIZE;
                                    end if;
                                    cpu_state <= CPU_IDLE;
                                    if operation_type = '0' then
                                        cpu_rd_req_out <= '0';
                                    else
                                        cpu_wr_req_out <= '0';
                                    end if;
                                    cache_state <= CACHE_CHECK;
                                else
                                    -- Cache-to-cache miss, go to SDRAM
                                    cache_state <= CACHE_SDRAM_ACCESS;
                                end if;
                            end if;
                        
                        when CACHE_SDRAM_ACCESS =>
                            if operation_type = '0' then
                                read_en <= '1';
                            else
                                write_en <= '1';
                                Sdram_data_out <= current_data;
                            end if;
                            Sdram_addr <= current_address;
                            
                            -- Allocate cache line
                            empty_index := find_empty_line(cache_mem);
                            if empty_index >= 0 then
                                cache_mem(empty_index).valid <= '1';
                                cache_mem(empty_index).address <= current_address;
                                if operation_type = '0' then
                                    cache_mem(empty_index).data <= Sdram_data_in;
                                    cache_mem(empty_index).msi_state <= MSI_SHARED;
                                else
                                    cache_mem(empty_index).data <= current_data;
                                    cache_mem(empty_index).msi_state <= MSI_MODIFIED;
                                end if;
                            else
                                -- Evict using round-robin
                                if cache_mem(evict_index).msi_state = MSI_MODIFIED then
                                    write_en <= '1';
                                    Sdram_addr <= cache_mem(evict_index).address;
                                    Sdram_data_out <= cache_mem(evict_index).data;
                                end if;
                                cache_mem(evict_index).valid <= '1';
                                cache_mem(evict_index).address <= current_address;
                                if operation_type = '0' then
                                    cache_mem(evict_index).data <= Sdram_data_in;
                                    cache_mem(evict_index).msi_state <= MSI_SHARED;
                                else
                                    cache_mem(evict_index).data <= current_data;
                                    cache_mem(evict_index).msi_state <= MSI_MODIFIED;
                                end if;
                                evict_index <= (evict_index + 1) mod CACHE_SIZE;
                            end if;
                            
                            cpu_state <= CPU_IDLE;
                            if operation_type = '0' then
                                cpu_rd_req_out <= '0';
                            else
                                cpu_wr_req_out <= '0';
                            end if;
                            cache_state <= CACHE_CHECK;
                    end case;
                
                when others =>
                    cpu_state <= CPU_IDLE;
            end case;
        end if;
    end process;

end Behavioral;
