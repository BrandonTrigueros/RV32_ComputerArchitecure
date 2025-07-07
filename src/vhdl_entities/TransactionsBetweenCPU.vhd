library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TransactionsBetweenCPU is
  port(
    clk             : in  std_logic;                    -- system clock
    rst             : in  std_logic;                    -- synchronous reset
    cpu0_prio       : in  std_logic;                    -- arbitration priority for CPU0
    cpu1_prio       : in  std_logic;                    -- arbitration priority for CPU1
    cpu0_wantedAddr : in  std_logic_vector(2 downto 0); -- CPU0 target address
    cpu1_wantedAddr : in  std_logic_vector(2 downto 0)  -- CPU1 target address
  );
end entity TransactionsBetweenCPU;

architecture bdf_type of TransactionsBetweenCPU is

  -- CPU core component
  component CPU_Core is
    port(
      clk                          : in  std_logic;
      reset                        : in  std_logic;
      priority                     : in  std_logic;
      cpu_wr_req_in                : in  std_logic;
      cpu_rd_req_in                : in  std_logic;
      cache_to_cache_resp_in_ready: in  std_logic;
      cache_to_cache_resp_in       : in  std_logic;
      cache_to_cache_req_in        : in  std_logic;
      cache_to_cache_req_address_in: in  std_logic_vector(2 downto 0);
      cache_to_cache_resp_in_data  : in  std_logic_vector(31 downto 0);
      cpu_req_addr_in              : in  std_logic_vector(2 downto 0);
      Sdram_data_in                : in  std_logic_vector(31 downto 0);
      wantedAddress                : in  std_logic_vector(2 downto 0);
      read_en                      : out std_logic;
      write_en                     : out std_logic;
      cpu_wr_req_out               : out std_logic;
      cpu_rd_req_out               : out std_logic;
      cache_to_cache_resp_out_ready: out std_logic;
      cache_to_cache_resp_out      : out std_logic;
      cache_to_cache_req_out       : out std_logic;
      cache_to_cache_req_address_out: out std_logic_vector(2 downto 0);
      cache_to_cache_resp_out_data : out std_logic_vector(31 downto 0);
      cpu_req_addr_out             : out std_logic_vector(2 downto 0);
      Sdram_addr                   : out std_logic_vector(2 downto 0);
      Sdram_data_out               : out std_logic_vector(31 downto 0)
    );
  end component;


  -- SDRAM component
  component sdram is
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
  end component;

  -- Internal signals for cache‐to‐cache traffic
  signal cpu0_cache_to_cache_req              : std_logic;
  signal cpu0_cache_to_cache_req_addr         : std_logic_vector(2 downto 0);
  signal cpu0_cache_to_cache_resp_data        : std_logic_vector(31 downto 0);
  signal cpu0_cache_to_cache_response         : std_logic;
  signal cpu0_cache_to_cache_response_out_ready : std_logic;
  signal cpu0_wr_req_out                      : std_logic;
  signal cpu0_rd_req_out                      : std_logic;
  signal cpu0_req_addr_out                    : std_logic_vector(2 downto 0);

  signal cpu1_cache_to_cache_req              : std_logic;
  signal cpu1_cache_to_cache_req_addr         : std_logic_vector(2 downto 0);
  signal cpu1_cache_to_cache_resp_data        : std_logic_vector(31 downto 0);
  signal cpu1_cache_to_cache_response         : std_logic;
  signal cpu1_cache_to_cache_response_out_ready : std_logic;
  signal cpu1_wr_req_out                      : std_logic;
  signal cpu1_rd_req_out                      : std_logic;
  signal cpu1_req_addr_out                    : std_logic_vector(2 downto 0);

  -- Read/Write enable flags from each CPU
  signal r_en1  : std_logic;
  signal wr_en1 : std_logic;
  signal r_en2  : std_logic;
  signal wr_en2 : std_logic;

  -- Combined "ready" lines into SDRAM
  signal ready1_sig : std_logic;
  signal ready2_sig : std_logic;

  -- Address buses from CPU → SDRAM
  signal sdram_addr1 : std_logic_vector(2 downto 0);
  signal sdram_addr2 : std_logic_vector(2 downto 0);

  -- Data buses CPU → SDRAM
  signal sdram_data_out1 : std_logic_vector(31 downto 0);
  signal sdram_data_out2 : std_logic_vector(31 downto 0);

  -- Data buses SDRAM → CPU
  signal sdram_data_in1  : std_logic_vector(31 downto 0);
  signal sdram_data_in2  : std_logic_vector(31 downto 0);

begin

  -- Generate "ready" handshake for SDRAM ports
  ready1_sig <= wr_en1 or r_en1;
  ready2_sig <= wr_en2 or r_en2;

  -- CPU Core #0 instance
  core0: CPU_Core
    port map(
      clk                            => clk,
      reset                          => rst,
      priority                       => cpu0_prio,
      cpu_wr_req_in                  => cpu1_wr_req_out,
      cpu_rd_req_in                  => cpu1_rd_req_out,
      cache_to_cache_resp_in_ready   => cpu1_cache_to_cache_response_out_ready,
      cache_to_cache_resp_in         => cpu1_cache_to_cache_response,
      cache_to_cache_req_in          => cpu1_cache_to_cache_req,
      cache_to_cache_req_address_in  => cpu1_cache_to_cache_req_addr,
      cache_to_cache_resp_in_data    => cpu1_cache_to_cache_resp_data,
      cpu_req_addr_in                => cpu1_req_addr_out,
      Sdram_data_in                  => sdram_data_in1,     -- from SDRAM
      wantedAddress                  => cpu0_wantedAddr,
      read_en                        => r_en1,
      write_en                       => wr_en1,
      cpu_wr_req_out                 => cpu0_wr_req_out,
      cpu_rd_req_out                 => cpu0_rd_req_out,
      cache_to_cache_resp_out_ready  => cpu0_cache_to_cache_response_out_ready,
      cache_to_cache_resp_out        => cpu0_cache_to_cache_response,
      cache_to_cache_req_out         => cpu0_cache_to_cache_req,
      cache_to_cache_req_address_out => cpu0_cache_to_cache_req_addr,
      cache_to_cache_resp_out_data   => cpu0_cache_to_cache_resp_data,
      cpu_req_addr_out               => cpu0_req_addr_out,
      Sdram_addr                     => sdram_addr1,         -- to SDRAM
      Sdram_data_out                 => sdram_data_out1      -- to SDRAM
    );

  -- CPU Core #1 instance
  core1: CPU_Core
    port map(
      clk                            => clk,
      reset                          => rst,
      priority                       => cpu1_prio,
      cpu_wr_req_in                  => cpu0_wr_req_out,
      cpu_rd_req_in                  => cpu0_rd_req_out,
      cache_to_cache_resp_in_ready   => cpu0_cache_to_cache_response_out_ready,
      cache_to_cache_resp_in         => cpu0_cache_to_cache_response,
      cache_to_cache_req_in          => cpu0_cache_to_cache_req,
      cache_to_cache_req_address_in  => cpu0_cache_to_cache_req_addr,
      cache_to_cache_resp_in_data    => cpu0_cache_to_cache_resp_data,
      cpu_req_addr_in                => cpu0_req_addr_out,
      Sdram_data_in                  => sdram_data_in2,     -- from SDRAM
      wantedAddress                  => cpu1_wantedAddr,
      read_en                        => r_en2,
      write_en                       => wr_en2,
      cpu_wr_req_out                 => cpu1_wr_req_out,
      cpu_rd_req_out                 => cpu1_rd_req_out,
      cache_to_cache_resp_out_ready  => cpu1_cache_to_cache_response_out_ready,
      cache_to_cache_resp_out        => cpu1_cache_to_cache_response,
      cache_to_cache_req_out         => cpu1_cache_to_cache_req,
      cache_to_cache_req_address_out => cpu1_cache_to_cache_req_addr,
      cache_to_cache_resp_out_data   => cpu1_cache_to_cache_resp_data,
      cpu_req_addr_out               => cpu1_req_addr_out,
      Sdram_addr                     => sdram_addr2,         -- to SDRAM
      Sdram_data_out                 => sdram_data_out2      -- to SDRAM
    );

  -- SDRAM instance (port‐interleaved two‐port memory)
  sdram0: sdram
    port map(
      clk        => clk,
      reset      => rst,
      operation1 => wr_en1,           -- write when wr_en1='1'
      operation2 => wr_en2,           -- write when wr_en2='1'
      ready1     => ready1_sig,
      ready2     => ready2_sig,
      addr1      => sdram_addr1,
      addr2      => sdram_addr2,
      data_in1   => sdram_data_out1,  -- CPU0 → SDRAM
      data_in2   => sdram_data_out2,  -- CPU1 → SDRAM
      data_out1  => sdram_data_in1,   -- SDRAM → CPU0
      data_out2  => sdram_data_in2    -- SDRAM → CPU1
    );

end architecture bdf_type;
