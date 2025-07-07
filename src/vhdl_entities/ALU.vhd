library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ALU is
  port (
    A   : in  STD_LOGIC_VECTOR(31 downto 0);
    B   : in  STD_LOGIC_VECTOR(31 downto 0);
    Op  : in  STD_LOGIC_VECTOR(6 downto 0);  -- solo Op(2 downto 0) importa
         -- 000 = ADD
         -- 001 = SUB
         -- 010 = AND
         -- 011 = OR
         -- 100 = XOR
         -- 101 = SLL
         -- 110 = SRL
         -- 111 = SRA
    Y   : out STD_LOGIC_VECTOR(31 downto 0)
  );
end entity ALU;

architecture Behavioral of ALU is
begin
  process(A, B, Op)
    variable tmp    : STD_LOGIC_VECTOR(31 downto 0);
    variable carry  : STD_LOGIC;
    variable i      : integer range 0 to 31;
    variable Binv   : STD_LOGIC_VECTOR(31 downto 0);
    variable shamt  : integer range 0 to 31;
  begin
    -- 1) Calcular shift-amount (5 LSB de B)
    shamt := 0;
    for i in 0 to 4 loop
      if B(i) = '1' then
        shamt := shamt + (2**i);
      end if;
    end loop;

    -- 2) Inicializar
    tmp   := (others => '0');
    carry := '0';

    -- 3) Seleccionar operación
    case Op(2 downto 0) is

      when "000" =>  -- ADD
        for i in 0 to 31 loop
          tmp(i)  := A(i) xor B(i) xor carry;
          carry   := (A(i) and B(i)) or (carry and (A(i) xor B(i)));
        end loop;

      when "001" =>  -- SUB = A + not(B) + 1
        for i in 0 to 31 loop
          Binv(i) := not B(i);
        end loop;
        carry := '1';
        for i in 0 to 31 loop
          tmp(i)  := A(i) xor Binv(i) xor carry;
          carry   := (A(i) and Binv(i)) or (carry and (A(i) xor Binv(i)));
        end loop;

      when "010" =>  -- AND
        for i in 0 to 31 loop
          tmp(i) := A(i) and B(i);
        end loop;

      when "011" =>  -- OR
        for i in 0 to 31 loop
          tmp(i) := A(i) or B(i);
        end loop;

      when "100" =>  -- XOR
        for i in 0 to 31 loop
          tmp(i) := A(i) xor B(i);
        end loop;

      when "101" =>  -- SLL (logical left)
        for i in 31 downto 0 loop
          if i - shamt >= 0 then
            tmp(i) := A(i - shamt);
          else
            tmp(i) := '0';
          end if;
        end loop;

      when "110" =>  -- SRL (logical right)
        for i in 0 to 31 loop
          if i + shamt <= 31 then
            tmp(i) := A(i + shamt);
          else
            tmp(i) := '0';
          end if;
        end loop;

      when "111" =>  -- SRA (arithmetic right)
        for i in 0 to 31 loop
          if i + shamt <= 31 then
            tmp(i) := A(i + shamt);
          else
            tmp(i) := A(31);  -- rellena con el bit de signo
          end if;
        end loop;

      when others =>
        tmp := (others => '0');
    end case;

    -- 4) Entregar resultado
    Y <= tmp;
  end process;
end architecture Behavioral;
