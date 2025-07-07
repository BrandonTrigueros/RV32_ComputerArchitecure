# Guía de Debug Mejorada para el Sistema de Caché

## Cambios Implementados

### 1. Salidas de Debug Añadidas
El componente `TransactionsBetweenCPU` ahora incluye estas salidas de debug:

```vhdl
-- DEBUG OUTPUTS
debug_cpu0_state     : out std_logic_vector(2 downto 0); -- CPU0 state
debug_cpu1_state     : out std_logic_vector(2 downto 0); -- CPU1 state  
debug_cache0_state   : out std_logic_vector(2 downto 0); -- Cache0 state
debug_cache1_state   : out std_logic_vector(2 downto 0); -- Cache1 state
debug_sdram_ready    : out std_logic;                    -- SDRAM ready
debug_cpu0_hit       : out std_logic;                    -- CPU0 cache hit
debug_cpu1_hit       : out std_logic;                    -- CPU1 cache hit
debug_reset_active   : out std_logic                     -- Reset status
```

### 2. Conexiones de Debug en Logisim
Para visualizar estas señales, conecta LEDs a las salidas de debug:

```
Component TransactionsBetweenCPU:
├── Debug Outputs (conectar a LEDs de 3 bits):
│   ├── debug_cpu0_state     → LED Bank 1
│   ├── debug_cpu1_state     → LED Bank 2
│   ├── debug_cache0_state   → LED Bank 3
│   ├── debug_cache1_state   → LED Bank 4
│   └── Debug Single LEDs:
│       ├── debug_sdram_ready → LED
│       ├── debug_cpu0_hit    → LED
│       ├── debug_cpu1_hit    → LED
│       └── debug_reset_active → LED
```

## Tabla de Estados para Debug

### Estados CPU (3 bits)
| Valor | Estado | Descripción |
|-------|---------|-------------|
| 000   | CPU_IDLE | CPU esperando solicitud |
| 001   | CPU_READ | CPU procesando lectura |
| 010   | CPU_WRITE | CPU procesando escritura |
| 011   | CPU_WAIT_CACHE | CPU esperando cache |
| 100   | CPU_WAIT_SDRAM | CPU esperando SDRAM |
| 111   | ERROR | Estado inválido |

### Estados Cache (3 bits)
| Valor | Estado | Descripción |
|-------|---------|-------------|
| 000   | CACHE_CHECK | Verificando hit/miss |
| 001   | CACHE_HIT | Cache hit detectado |
| 010   | CACHE_MISS | Cache miss detectado |
| 011   | CACHE_COHERENCE | Protocolo MSI |
| 100   | CACHE_SDRAM_ACCESS | Accediendo SDRAM |
| 101   | CACHE_SDRAM_WAIT | Esperando SDRAM |
| 110   | CACHE_EVICTION | Evictando línea |
| 111   | ERROR | Estado inválido |

## Procedimiento de Debug Detallado

### Paso 1: Verificación de Reset
**Setup:**
- Conecta todas las salidas de debug a LEDs
- Configura el reloj a 1 Hz para observar paso a paso

**Acción:**
- Presiona el botón Reset por 1 ciclo

**Resultados Esperados:**
- `debug_reset_active` = 1 (durante reset)
- `debug_cpu0_state` = 000 (CPU_IDLE)
- `debug_cpu1_state` = 000 (CPU_IDLE)
- `debug_cache0_state` = 000 (CACHE_CHECK)
- `debug_cache1_state` = 000 (CACHE_CHECK)
- `debug_sdram_ready` = 1 (SDRAM inicializado)
- `debug_cpu0_hit` = 0
- `debug_cpu1_hit` = 0
- `cpu0_ready` = 0
- `cpu1_ready` = 0

### Paso 2: Prueba de Lectura CPU0 con Debug
**Setup:**
- `cpu0_wantedAddr` = 0x1
- `cpu0_rw` = 0 (read)
- `cpu0_req` = 0 (inicialmente)

**Secuencia con Debug:**

#### Ciclo 1: Estado Inicial
- **Entrada:** `cpu0_req` = 0
- **Debug Esperado:**
  - `debug_cpu0_state` = 000 (CPU_IDLE)
  - `debug_cache0_state` = 000 (CACHE_CHECK)
  - `cpu0_ready` = 0

#### Ciclo 2: Iniciar Solicitud
- **Entrada:** `cpu0_req` = 1
- **Debug Esperado:**
  - `debug_cpu0_state` = 001 (CPU_READ)
  - `debug_cache0_state` = 000 (CACHE_CHECK)
  - `cpu0_ready` = 0

#### Ciclo 3: Verificar Cache
- **Entrada:** Mantener `cpu0_req` = 1
- **Debug Esperado:**
  - `debug_cpu0_state` = 001 (CPU_READ)
  - `debug_cache0_state` = 010 (CACHE_MISS) - primera vez
  - `debug_cpu0_hit` = 0
  - `cpu0_ready` = 0

#### Ciclo 4: Acceso SDRAM
- **Debug Esperado:**
  - `debug_cpu0_state` = 001 (CPU_READ)
  - `debug_cache0_state` = 100 (CACHE_SDRAM_ACCESS)
  - `debug_sdram_ready` = 1
  - `cpu0_ready` = 0

#### Ciclos 5-7: Espera SDRAM
- **Debug Esperado:**
  - `debug_cpu0_state` = 001 (CPU_READ)
  - `debug_cache0_state` = 101 (CACHE_SDRAM_WAIT)
  - `cpu0_ready` = 0

#### Ciclo 8: Completar Operación
- **Debug Esperado:**
  - `debug_cpu0_state` = 011 (CPU_WAIT_CACHE)
  - `debug_cache0_state` = 001 (CACHE_HIT)
  - `cpu0_ready` = 1
  - `cpu0_data_out` = 0x11111111

#### Ciclo 9: Finalizar Handshake
- **Entrada:** `cpu0_req` = 0
- **Debug Esperado:**
  - `debug_cpu0_state` = 000 (CPU_IDLE)
  - `debug_cache0_state` = 000 (CACHE_CHECK)
  - `cpu0_ready` = 0

## Diagnóstico de Problemas

### Si cpu0_ready nunca se activa:

1. **Verificar Reset:**
   - ¿`debug_reset_active` funciona correctamente?
   - ¿Estados se resetean a valores correctos?

2. **Verificar Transición CPU_IDLE → CPU_READ:**
   - ¿`debug_cpu0_state` cambia de 000 a 001?
   - Si NO: Problema en detección de `cpu0_req`

3. **Verificar Transición CACHE_CHECK → CACHE_MISS:**
   - ¿`debug_cache0_state` cambia de 000 a 010?
   - Si NO: Problema en lógica de hit/miss

4. **Verificar Acceso SDRAM:**
   - ¿`debug_cache0_state` cambia de 010 a 100?
   - ¿`debug_sdram_ready` = 1?
   - Si NO: Problema en interfaz SDRAM

5. **Verificar Espera SDRAM:**
   - ¿`debug_cache0_state` cambia de 100 a 101?
   - ¿Permanece en 101 por 2-3 ciclos?
   - Si NO: Problema en contador de ciclos

6. **Verificar Completado:**
   - ¿`debug_cpu0_state` cambia de 001 a 011?
   - ¿`cpu0_ready` = 1?
   - Si NO: Problema en lógica de completado

### Si cpu0_data_out no muestra datos correctos:

1. **Verificar datos SDRAM:**
   - ¿SDRAM inicializado correctamente?
   - ¿Dirección 0x1 contiene 0x11111111?

2. **Verificar cache:**
   - ¿Datos se almacenan correctamente en cache después de lectura SDRAM?
   - ¿Cache hit funciona en lecturas posteriores?

## Configuración de Pines en Logisim

### Entradas de Control
```
Pin Name            | Width | Value
--------------------|-------|-------
clk                 | 1     | Clock
rst                 | 1     | Button
cpu0_prio           | 1     | 1
cpu1_prio           | 1     | 0
cpu0_wantedAddr     | 3     | 0x1
cpu0_data_in        | 32    | 0x00000000
cpu0_req            | 1     | 0→1 (para iniciar)
cpu0_rw             | 1     | 0 (read)
cpu1_*              | *     | 0 (todas)
```

### Salidas de Debug
```
Pin Name            | Width | Connection
--------------------|-------|------------
debug_cpu0_state    | 3     | LED Bank 1
debug_cpu1_state    | 3     | LED Bank 2
debug_cache0_state  | 3     | LED Bank 3
debug_cache1_state  | 3     | LED Bank 4
debug_sdram_ready   | 1     | LED
debug_cpu0_hit      | 1     | LED
debug_cpu1_hit      | 1     | LED
debug_reset_active  | 1     | LED
cpu0_data_out       | 32    | Hex Display
cpu1_data_out       | 32    | Hex Display
cpu0_ready          | 1     | LED
cpu1_ready          | 1     | LED
```

## Checklist de Verificación

### Antes de la Prueba:
- [ ] Todas las salidas de debug conectadas a LEDs
- [ ] Reloj configurado a 1 Hz
- [ ] Reset aplicado correctamente
- [ ] Entradas configuradas según tabla

### Durante la Prueba:
- [ ] Estados CPU progresan correctamente
- [ ] Estados Cache progresan correctamente
- [ ] SDRAM ready siempre activo
- [ ] Handshake completo funciona

### Si Falla:
- [ ] Documentar secuencia de estados observada
- [ ] Comparar con secuencia esperada
- [ ] Identificar en qué paso se detiene
- [ ] Revisar lógica específica de ese paso

Con estas mejoras de debug, deberías poder identificar exactamente dónde se detiene el proceso y por qué `cpu0_ready` nunca se activa.
