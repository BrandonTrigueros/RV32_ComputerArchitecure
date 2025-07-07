library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FIFO is
  port(
    clk            : in  std_logic;	-- system clock
    rst            : in  std_logic;	-- synchronous reset

    -- CPU0 interface
    cpu0_read_in   : in  std_logic;					-- CPU0 read request (1 = read)
    cpu0_write_in  : in  std_logic;					-- CPU0 write request (1 = write)
    cpu0_data_in   : in  std_logic_vector(31 downto 0);	-- CPU0 write data
    cpu0_addr      : in  std_logic_vector(2 downto 0);	-- CPU0 address

    -- CPU1 interface
    cpu1_read_in   : in  std_logic;
    cpu1_write_in  : in  std_logic;
    cpu1_data_in   : in  std_logic_vector(31 downto 0);
    cpu1_addr      : in  std_logic_vector(2 downto 0);

    -- Output to SDRAM
    read_out       : out std_logic;	-- 1 = perform read
    write_out      : out std_logic;	-- 1 = perform write

    addr_out       : out std_logic_vector(2 downto 0);	-- address to SDRAM
    data_out       : out std_logic_vector(31 downto 0)	-- data to SDRAM (for writes)
  );
end entity FIFO;

architecture behavior of FIFO is
  -- record and array _types_
  type sdramrequest is record
    requester : std_logic;			-- '0' = CPU0, '1' = CPU1
    operation : std_logic;            	-- 0 = read, 1 = write
    address   : std_logic_vector(2 downto 0);
    data      : std_logic_vector(31 downto 0);
    valid     : std_logic;
  end record sdramrequest;

  -- circular buffer of 1024 requests
  type sdramRequestBuffer is array(0 to 1023) of sdramrequest;

  -- allocate the buffer signal 
  signal request_buf : sdramRequestBuffer := (
    others => (
      requester => '0',
      operation => '0',
      address   => (others => '0'),
      data      => (others => '0'),
      valid     => '0'
    )
  );

  -- track which CPU was last served 
  signal previousRequester : std_logic;  -- 0 is cpu0, 1 is cpu1

begin

  process(clk, rst)
  begin
    if rst = '1' then
    	 -- synchronous reset: clear buffer and outputs
      -- clear buffer on reset
      request_buf <= (others => (
        requester => '0',
        operation => '0',
        address   => (others => '0'),
        data      => (others => '0'),
        valid     => '0'
      ));
      read_out  <= '0';
      write_out <= '0';
      previousRequester <= '0';

    elsif rising_edge(clk) then

    	 -- if there's a pending SDRAM request at buffer slot 0
      if request_buf(0).valid = '1' then
        -- dequeue slot 0
        read_out  <= not request_buf(0).operation;
        write_out <=     request_buf(0).operation;
        addr_out  <=     request_buf(0).address;
        data_out  <=     request_buf(0).data;

        -- once served, invalidate this slot
        request_buf(0).valid <= '0';

      else
      -- buffer is empty → directly arbitrate between CPU0 & CPU1

        -- 1) No requests from either CPU
        if cpu0_read_in='0' and cpu0_write_in='0'
           and cpu1_read_in='0' and cpu1_write_in='0' then

          read_out  <= '0';
          write_out <= '0';

        -- 2) CPU1 wants to write only
        elsif cpu0_read_in='0' and cpu0_write_in='0'
           and cpu1_read_in='0' and cpu1_write_in='1' then

          read_out          <= '0';
          write_out         <= '1';
          previousRequester <= '1';

        -- 3) CPU1 wants to read only
        elsif cpu0_read_in='0' and cpu0_write_in='0'
           and cpu1_read_in='1' and cpu1_write_in='0' then

          read_out          <= '1';
          write_out         <= '0';
          previousRequester <= '1';

        -- 4) CPU0 wants to write only
        elsif cpu0_read_in='0' and cpu0_write_in='1'
           and cpu1_read_in='0' and cpu1_write_in='0' then

          read_out          <= '0';
          write_out         <= '1';
          previousRequester <= '0';

        -- 5) CPU0 wants to read only
        elsif cpu0_read_in='1' and cpu0_write_in='0'
           and cpu1_read_in='0' and cpu1_write_in='0' then

          read_out          <= '1';
          write_out         <= '0';
          previousRequester <= '0';

        -- 6) Both CPUs want to read → enqueue CPU1's read
        elsif cpu0_read_in='1' and cpu0_write_in='0'
           and cpu1_read_in='1' and cpu1_write_in='0' then

          read_out          <= '1';
          write_out         <= '0';
          previousRequester <= '0';

          request_buf(0).requester <= '1';        -- from CPU1
          request_buf(0).operation <= '0';        -- read
          request_buf(0).address   <= cpu1_addr;
          request_buf(0).valid     <= '1';

        -- 7) CPU0 read & CPU1 write → enqueue CPU1's write
        elsif cpu0_read_in='1' and cpu0_write_in='0'
           and cpu1_read_in='0' and cpu1_write_in='1' then

          read_out          <= '1';
          write_out         <= '0';
          previousRequester <= '0';

          request_buf(0).requester <= '1';
          request_buf(0).operation <= '1';        -- write
          request_buf(0).address   <= cpu1_addr;
          request_buf(0).data      <= cpu1_data_in;
          request_buf(0).valid     <= '1';

        -- 8) CPU0 write & CPU1 read → enqueue CPU1's read
        elsif cpu0_read_in='0' and cpu0_write_in='1'
           and cpu1_read_in='1' and cpu1_write_in='0' then

          read_out          <= '0';
          write_out         <= '1';
          previousRequester <= '0';

          request_buf(0).requester <= '1';
          request_buf(0).operation <= '0';        -- read
          request_buf(0).address   <= cpu1_addr;
          request_buf(0).valid     <= '1';

        -- 9) Both CPUs want to write → enqueue CPU1's write
        elsif cpu0_read_in='0' and cpu0_write_in='1'
           and cpu1_read_in='0' and cpu1_write_in='1' then

          read_out          <= '0';
          write_out         <= '1';
          previousRequester <= '0';

          request_buf(0).requester <= '1';
          request_buf(0).operation <= '1';
          request_buf(0).address   <= cpu1_addr;
          request_buf(0).data      <= cpu1_data_in;
          request_buf(0).valid     <= '1';

        end if;
      end if;

    end if;
  end process;

end architecture behavior;
