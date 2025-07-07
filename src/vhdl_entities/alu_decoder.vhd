library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_decoder is
  port (
    opcode  : in  std_logic_vector(6 downto 0);
    funct3  : in  std_logic_vector(2 downto 0);
    funct7  : in  std_logic_vector(6 downto 0);
    
    instr_code : out std_logic_vector(3 downto 0);
    is_imm     : out std_logic
  );
end entity alu_decoder;

architecture rtl of alu_decoder is

  -- Códigos internos para cada operación
  subtype icode_t is std_logic_vector(3 downto 0);
  constant I_ADD   : icode_t := "0000";
  constant I_SUB   : icode_t := "0001";
  constant I_ADDI  : icode_t := "0010";
  constant I_AND   : icode_t := "0011";
  constant I_OR    : icode_t := "0100";
  constant I_XOR   : icode_t := "0101";
  constant I_ANDI  : icode_t := "0110";
  constant I_ORI   : icode_t := "0111";
  constant I_XORI  : icode_t := "1000";
  constant I_SLL   : icode_t := "1001";
  constant I_SRL   : icode_t := "1010";
  constant I_SRA   : icode_t := "1011";
  constant I_NONE  : icode_t := "1111";  -- ningún match

begin

  process(opcode, funct3, funct7)
  begin
    -- Valor por defecto
    instr_code <= I_NONE;
    is_imm     <= '0';

    case opcode is

      -- R-TYPE: opcode = "0110011"
      when "0110011" =>
        is_imm <= '0';
        case funct3 is
          when "000" =>
            if funct7 = "0000000" then
                instr_code <= I_ADD;
            elsif funct7 = "0100000" then
                instr_code <= I_SUB;
            end if;
          when "111" =>
            instr_code <= I_AND;
          when "110" =>
            instr_code <= I_OR;
          when "100" =>
            instr_code <= I_XOR;
          when "001" =>
            instr_code <= I_SLL;
          when "101" =>
            if funct7 = "0000000" then
              instr_code <= I_SRL;
            elsif funct7 = "0100000" then
              instr_code <= I_SRA;
            end if;
          when others =>
            instr_code <= I_NONE;
        end case;

      -- I-TYPE aritméticas: opcode = "0010011"
      when "0010011" =>
        is_imm <= '1';
        case funct3 is
          when "000" =>
            instr_code <= I_ADDI;
          when "111" =>
            instr_code <= I_ANDI;
          when "110" =>
            instr_code <= I_ORI;
          when "100" =>
            instr_code <= I_XORI;
          -- (si deseases SLLI, SRLI, SRAI, habría que chequear funct7 también)
          when others =>
            instr_code <= I_NONE;
        end case;

      when others =>
        instr_code <= I_NONE;
        is_imm     <= '0';
    end case;
  end process;

end architecture rtl;
